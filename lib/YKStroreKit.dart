
import 'package:in_app_purchase/in_app_purchase.dart';

class _YKStoreKitCurrentModel {

  String orderId = "";

  String customId = "";

  late ProductDetails currentDetail;

  _YKStoreKitCurrentModel({required this.orderId, required this.customId});

}

mixin YKStoreKitMainProtocol {

  Future<bool> checkOrder(String protocol, String orderId, String customerId);

}

abstract class YKStoreKitLogController {

  log(String message);

  error(String error);
}

class YKStoreKit {

  static YKStoreKit? _instance;

  YKStoreKitMainProtocol? _protocol;

  YKStoreKitLogController? _controller;

  _YKStoreKitCurrentModel? _currentModel;

  factory YKStoreKit._getInstance() {
    _instance ??= YKStoreKit._();
    return _instance!;
  }

  YKStoreKit._();

  static setupMainProtocol(YKStoreKitMainProtocol protocol) {
    YKStoreKit._getInstance()._protocol = protocol;
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
      }

    } else {
      _controller?.error(response.error!.message);
    }

  }

  _saveCache(_YKStoreKitCurrentModel model) {

  }

  _deleCache(String customerId) {

  }

  _YKStoreKitCurrentModel getModel(String customerId) {
    return _YKStoreKitCurrentModel(orderId: "", customId: "");
  }
}