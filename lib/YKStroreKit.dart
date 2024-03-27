
import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';

class _YKStoreKitCurrentModel {

  String orderId = "";

  String customId = "";

  late ProductDetails currentDetail;

  _YKStoreKitCurrentModel({required this.orderId, required this.customId});

}

class YKStoreKitMainController {

  final Future<bool> Function(String protocol, String orderId, String customerId) checkOrderCallBack;

  const YKStoreKitMainController(this.checkOrderCallBack);
}

class YKStoreKitLogController {

  void Function(String message)? logCallBack;

  void Function(String errorMessage)? errorCallBack;

  YKStoreKitLogController({this.logCallBack, this.errorCallBack});
}

class YKStoreKit {

  static YKStoreKit? _instance;

  YKStoreKitMainController? _mainController;

  YKStoreKitLogController? _controller;

  _YKStoreKitCurrentModel? _currentModel;

  late StreamSubscription streamSubscription;

  factory YKStoreKit._getInstance() {
    _instance ??= YKStoreKit._();
    return _instance!;
  }

  YKStoreKit._() {
    streamSubscription = InAppPurchase.instance.purchaseStream.listen((event) {

      event.forEach((PurchaseDetails purchaseDetails) async {
        if (purchaseDetails.status == PurchaseStatus.pending) {
          // 购买凭证创建中

        } else {
          if (purchaseDetails.status == PurchaseStatus.error) {
            // 购买失败
          } else if (purchaseDetails.status == PurchaseStatus.purchased || purchaseDetails.status == PurchaseStatus.restored) {
            // 购买成功

            try {

              final result = await _mainController?.checkOrderCallBack("",_currentModel!.orderId,_currentModel!.customId) ?? false;
              if (result) {
                if (purchaseDetails.pendingCompletePurchase) {
                  //核销商品
                  await InAppPurchase.instance.completePurchase(purchaseDetails);
                }
              }

            } catch (e) {
              _error(e.toString());
            } finally {

            }
          }


        }
      });
    });
  }

  static setupMainProtocol(YKStoreKitMainController mainController) {
    //禁止重复操作
    if (YKStoreKit._getInstance()._mainController != null) {
      YKStoreKit._getInstance()._mainController = mainController;
    }
  }

  static order(String orderId, String customerId, {YKStoreKitLogController? controller}) {
    YKStoreKit._getInstance()._order(orderId, customerId, controller);
  }


  _order(String orderId, String customerId, YKStoreKitLogController? controller) async {
    _controller = controller;
    _currentModel = _YKStoreKitCurrentModel(orderId: orderId, customId: customerId);
    Set<String> kIds = <String>{};
    kIds.add(orderId);
    final ProductDetailsResponse response = await InAppPurchase.instance.queryProductDetails(kIds);

    if (response.error != null) {
      ProductDetails? currentDetail;

      for (ProductDetails detail in response.productDetails) {
        if (detail.id == orderId) {
          currentDetail = detail;
        }
      }

      if (currentDetail != null) {
        _currentModel!.currentDetail = currentDetail;
        _toPay();
      } else {
        _error("找不到付费点");
      }


    } else {
      _error(response.error!.message);
    }

  }

  _toPay() {
    ProductDetails details = _currentModel!.currentDetail!;
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: details);
    InAppPurchase.instance.buyConsumable(purchaseParam: purchaseParam);
  }

  _log(String message) {

    _controller?.logCallBack?(message);
  }

  _error(String error) {
    
    _controller?.errorCallBack?(error);
  }

  _saveCache(_YKStoreKitCurrentModel model) {

  }

  _deleCache(String customerId) {

  }

  _YKStoreKitCurrentModel getModel(String customerId) {
    return _YKStoreKitCurrentModel(orderId: "", customId: "");
  }
}