import 'package:dio/dio.dart';
import '../../core/network/dio_client.dart';
import '../../core/constants/api_constants.dart';

class PaymentService {
  static Future<String> createCheckout() async {
    final response = await DioClient.instance.post(ApiConstants.createCheckout);
    return response.data['checkout_url'];
  }

  static Future<Map<String, dynamic>> getStatus() async {
    final response = await DioClient.instance.get(ApiConstants.paymentStatus);
    return response.data;
  }
}