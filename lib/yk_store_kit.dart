import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:yk_flutter_core/yk_file_manager.dart.dart';

class YKStorePayDetail {
  String _id = "";
  String _title = "";
  String _description = "";
  String _price = "";
  double _rawPrice = 0;
  String _currencyCode = "";
  String _currencySymbol = "";

  static YKStorePayDetail _make(ProductDetails details) {
    YKStorePayDetail model = YKStorePayDetail();
    model._id = details.id;
    model._title = details.title;
    model._description = details.description;
    model._price = details.price;
    model._rawPrice = details.rawPrice;
    model._currencyCode = details.currencyCode;
    model._currencySymbol = details.currencySymbol;

    return model;
  }

  ProductDetails _todetail() {
    return ProductDetails(
      id: id,
      title: title,
      description: description,
      price: price,
      rawPrice: rawPrice,
      currencyCode: currencyCode,
      currencySymbol: currencySymbol,
    );
  }

  String get id => _id;

  String get title => _title;

  String get description => _description;

  String get price => _price;

  double get rawPrice => _rawPrice;

  String get currencyCode => _currencyCode;

  String get currencySymbol => _currencySymbol;
}

class _YKStoreKitCurrentModel {
  String orderId = "";

  String customId = "";

  late PurchaseDetails currentDetail;

  _YKStoreKitCurrentModel({required this.orderId, required this.customId});

  Map<String, dynamic> tojson() {
    return {
      "orderId": orderId,
      "customId": customId,
      "currentDetail": {
        "purchaseID": currentDetail.purchaseID,
        "productID": currentDetail.productID,
        "verificationData": {
          "localVerificationData": currentDetail.verificationData.localVerificationData,
          "serverVerificationData": currentDetail.verificationData.serverVerificationData,
          "source": currentDetail.verificationData.source,
        },
        "transactionDate": currentDetail.transactionDate,
        "status": currentDetail.status.name,
        "pendingCompletePurchase": currentDetail.pendingCompletePurchase,
      }
    };
  }

  static _YKStoreKitCurrentModel make(Map<String, dynamic> dic) {
    _YKStoreKitCurrentModel model = _YKStoreKitCurrentModel(orderId: dic["orderId"], customId: dic["customId"]);
    Map<String, dynamic> currentDetail = dic["currentDetail"];
    Map<String, dynamic> verificationData = currentDetail["verificationData"];
    model.currentDetail = PurchaseDetails(
      productID: currentDetail["productID"] ?? "",
      purchaseID: currentDetail["purchaseID"],
      verificationData: PurchaseVerificationData(
          localVerificationData: verificationData["localVerificationData"],
          serverVerificationData: verificationData["serverVerificationData"],
          source: verificationData["source"]),
      transactionDate: currentDetail["transactionDate"],
      status: PurchaseStatus.values.firstWhere((e) => e.name == json, orElse: () => PurchaseStatus.error),
    );
    model.currentDetail.pendingCompletePurchase = currentDetail["pendingCompletePurchase"];

    return model;
  }
}

class _YKStoreKitMainController {
  final Future<bool> Function(String protocol, String applePayId, String customerId) checkOrderCallBack;

  const _YKStoreKitMainController(this.checkOrderCallBack);
}

class YKStoreKitLogDelegate {
  void Function(String message)? logCallBack;

  void Function(String errorMessage)? errorCallBack;

  Future<dynamic> Function()? loading;

  Future<void> Function()? disLoading;

  YKStoreKitLogDelegate({this.logCallBack, this.errorCallBack, this.loading, this.disLoading});
}

class YKStoreKit {
  static YKStoreKit? _instance;

  _YKStoreKitMainController? _mainController;

  YKStoreKitLogDelegate? _delegate;

  _YKStoreKitCurrentModel? _currentModel;

  late StreamSubscription streamSubscription;

  factory YKStoreKit._getInstance() {
    _instance ??= YKStoreKit._();
    return _instance!;
  }

  YKStoreKit._();

  static setupCheckOrder({required Future<bool> Function(String protocol, String applePayId, String customerId) callBack}) async {
    _YKStoreKitMainController mainController = _YKStoreKitMainController(callBack);

    //禁止重复操作
    if (YKStoreKit
        ._getInstance()
        ._mainController != null) {
      YKStoreKit
          ._getInstance()
          ._mainController = mainController;
    }

    final cacheModels = await YKStoreKit._getInstance()._getModels();


    for (final model in cacheModels) {
      String orderId = model.orderId;
      String customerId = model.customId;
      String verificationData = model.currentDetail.verificationData.serverVerificationData;

      final isFinish = await mainController.checkOrderCallBack(verificationData, orderId, customerId);
      if (isFinish) {
        YKStoreKit._getInstance()._deleteCache(orderId);
        YKStoreKit._getInstance()._log("支付完成:OrderId:$orderId, CustomerId:$customerId");
      } else {
        YKStoreKit._getInstance()._error("支付未完成:OrderId:$orderId, CustomerId:$customerId");
      }
    }

    //设置支付内容
    final available = await InAppPurchase.instance.isAvailable();
    if (!available) {}
    YKStoreKit
        ._getInstance()
        .streamSubscription = InAppPurchase.instance.purchaseStream.listen((event) async {

      for (final purchaseDetails in event) {
        if (purchaseDetails.status == PurchaseStatus.pending) {
          // 购买凭证创建中
          String orderId = purchaseDetails.productID;
          YKStoreKit._getInstance()._log("正在支付中:$orderId");
        } else {
          if (purchaseDetails.status == PurchaseStatus.error) {
            // 购买失败
            YKStoreKit._getInstance()._log(purchaseDetails.error?.message ?? "");
          } else if (purchaseDetails.status == PurchaseStatus.canceled) {
            //取消
            YKStoreKit._getInstance()._log("支付已取消 ${purchaseDetails.productID}");
          } else if (purchaseDetails.status == PurchaseStatus.purchased || purchaseDetails.status == PurchaseStatus.restored) {
            // 购买成功

            try {
              if (YKStoreKit
                  ._getInstance()
                  ._currentModel != null) {
                //MARK: 购买凭证保存到本地
                YKStoreKit
                    ._getInstance()
                    ._currentModel!
                    .currentDetail = purchaseDetails;
                await YKStoreKit._getInstance()._saveCache(YKStoreKit
                    ._getInstance()
                    ._currentModel!);
              }

              String orderId = purchaseDetails.productID;
              String customerId = YKStoreKit
                  ._getInstance()
                  ._currentModel
                  ?.customId ?? "";
              String vantData = purchaseDetails.verificationData.serverVerificationData;

              await YKStoreKit._getInstance()._disloading();
              final isFinish = await mainController.checkOrderCallBack(vantData, orderId, customerId);
              if (isFinish) {
                YKStoreKit._getInstance()._deleteCache(orderId);
                YKStoreKit._getInstance()._log("支付完成:OrderId:$orderId, CustomerId:$customerId");
              } else {
                YKStoreKit._getInstance()._error("支付未完成:OrderId:$orderId, CustomerId:$customerId");
              }
            } catch (e) {
              YKStoreKit._getInstance()._disloading();
              YKStoreKit._getInstance()._error(e.toString());
            } finally {}
          }

          //MARK: 统一都做完成操作
          if (purchaseDetails.pendingCompletePurchase) {
            //核销商品
            await InAppPurchase.instance.completePurchase(purchaseDetails);
            YKStoreKit
                ._getInstance()
                ._currentModel = null;
            YKStoreKit._getInstance()._log("已完成: ${purchaseDetails.productID}");
          }
        }
      }
    });
  }

  static setupDelegate({required YKStoreKitLogDelegate delegate}) {
    YKStoreKit._getInstance()._delegate = delegate;
  }

  static order({required String orderId, required String customerId}) {
    YKStoreKit._getInstance()._order(orderId, customerId, false);
  }

  static subscriptionOrder({required String subscriptionOrderId, required String customerId}) async {
    YKStoreKit._getInstance()._order(subscriptionOrderId, customerId, true);
  }

  static Future<List<YKStorePayDetail>> getDetail(List<String> orderIds) async {
    Set<String> kIds = <String>{};

    for (String order in orderIds) {
      kIds.add(order);
    }

    try {
      final ProductDetailsResponse response = await InAppPurchase.instance.queryProductDetails(kIds);

      if (response.error == null) {
        var list = List<YKStorePayDetail>.from(response.productDetails.map((e) => YKStorePayDetail._make(e)));

        return list;
      }
    } catch (e) {}

    return [];
  }

  static Future<void> requestReview() {
    return InAppReview.instance.requestReview();
  }

  _order(String orderId, String customerId, bool isNon) async {
    if (_currentModel != null) {
      if (_delegate?.errorCallBack != null) {
        _delegate?.errorCallBack!("上一单支付还未完成");
      }
      return;
    }

    _loading();
    try {
      Set<String> kIds = <String>{orderId};
      final ProductDetailsResponse response = await InAppPurchase.instance.queryProductDetails(kIds);

      if (response.error == null) {
        ProductDetails? currentDetail;

        for (ProductDetails detail in response.productDetails) {
          if (detail.id == orderId) {
            currentDetail = detail;
          }
        }

        if (currentDetail != null) {
          // 找到支付点：开启支付
          _currentModel = _YKStoreKitCurrentModel(orderId: orderId, customId: customerId);
          final PurchaseParam purchaseParam = PurchaseParam(productDetails: currentDetail!);
          if (isNon) {
            InAppPurchase.instance.buyNonConsumable(purchaseParam: purchaseParam);
          } else {
            InAppPurchase.instance.buyConsumable(purchaseParam: purchaseParam);
          }
        } else {
          _error("找不到付费点");
        }
      } else {
        _error(response.error!.message);
      }
    } catch (e) {
      _error("产生支付错误 ${e.toString()}");
    }
  }

  _log(String message) {
    if (_delegate?.logCallBack != null) {
      _delegate?.logCallBack!(message);
    }
  }

  _error(String error) {
    if (_delegate?.errorCallBack != null) {
      _delegate?.errorCallBack!(error);
    }
  }

  Future<dynamic> _loading() async {
    if (_delegate?.loading != null) {
      return _delegate?.loading!();
    }
  }

  Future<void> _disloading() async {
    if (_delegate?.disLoading != null) {
      return _delegate?.disLoading!();
    }
  }

  _saveCache(_YKStoreKitCurrentModel model) async {
    final file = await _getCacheFile();

    if (file != null) {
      final fileData = await file.readAsBytes();
      final data = utf8.decode(fileData as List<int>);
      var json_data = [];
      if (data.isNotEmpty) {
        json_data = jsonDecode(data);
      }

      json_data.add(model.tojson());

      String finalFinal = json.encode(json_data);

      file.writeAsBytes(utf8.encode(finalFinal));
    }
  }

  _deleteCache(String applePayId) async {
    final file = await _getCacheFile();

    if (file != null) {
      final fileData = await file.readAsBytes();
      final data = utf8.decode(fileData as List<int>);
      var json_data = [];
      if (data.isNotEmpty) {
        json_data = jsonDecode(data);
      }
      json_data.removeWhere((element) => (element["orderId"] == applePayId));

      String finalFinal = json.encode(json_data);

      file.writeAsBytes(utf8.encode(finalFinal));
    }
  }

  Future<List<_YKStoreKitCurrentModel>> _getModels() async {
    final file = await _getCacheFile();

    if (file != null) {
      final fileData = await file.readAsBytes();
      final data = utf8.decode(fileData as List<int>);
      var json_data = [];
      if (data.isNotEmpty) {
        json_data = jsonDecode(data);
      }

      final models = List<_YKStoreKitCurrentModel>.from(json_data.map((e) => _YKStoreKitCurrentModel.make(e)));

      return models;
    }

    return [];
  }

  Future<File?> _getCacheFile() async {
    try {
      final path = await YkFileManager.getDocumentPath();

      final folderPath = "$path/YKF/Store/store_cache";
      final dir = Directory(folderPath);

      final isExists = await dir.exists();

      if (!isExists) {
        await dir.create();
      }

      final storeFolderPath = "$folderPath/Store";
      final storeDir = Directory(storeFolderPath);

      final storeDirExists = await storeDir.exists();
      if (!storeDirExists) {
        await storeDir.create();
      }

      final file = await File("${storeDir.path}/store_cache");
      final fileExe = await file.exists();

      if (!fileExe) {
        file.writeAsBytes(utf8.encode("[]"));
      }

      _log("创建文件成功: ${file.path}");
      return file;
    } catch (e) {
      debugPrint("创建失败:${e.toString()}");

      return null;
    }
  }
}