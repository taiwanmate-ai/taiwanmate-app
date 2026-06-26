import "../utils/web_utils.dart";

class PaymentService {
  static void openCheckout({required String plan, required String fallbackUrl}) {
    try {
      webOpenUrl(fallbackUrl);
    } catch (e) {
    }
  }
}
