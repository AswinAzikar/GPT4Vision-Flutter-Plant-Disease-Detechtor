import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:gpt_vision_leaf_detect/constants/constants.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

// import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../constants/api_constants.dart';

class ApiService {
  final Dio dio = Dio();

  ApiService() {
    dio.interceptors.add(PrettyDioLogger(
      requestHeader: true,
      requestBody: true,
      responseBody: true,
      responseHeader: false,
      error: true,
      compact: true,
      maxWidth: 90,
      enabled: true,
    ));
  }

  Future<String> encodeImage(File image) async {
    final bytes = await image.readAsBytes();
    return base64Encode(bytes);
  }

  Future<String> sendMessageGPT({required String diseaseName}) async {
    try {
      final response = await dio.post(
        "$BASE_URL/chat/completions",
        options: Options(
          headers: {
            HttpHeaders.authorizationHeader: 'Bearer $API_KEY',
            HttpHeaders.contentTypeHeader: "application/json",
          },
        ),
        data: {
          "model": 'gpt-4o',
          "messages": [
            {
              "role": "user",
              "content":
                  "GPT, upon receiving the name of a plant disease, provide three precautionary measures to prevent or manage the disease. These measures should be concise, clear, and limited to one sentence each. No additional information or context is needed—only the three precautions in bullet-point format. The disease is $diseaseName",
            }
          ],
        },
      );

      final jsonResponse = response.data;

      if (jsonResponse['error'] != null) {
        // var a = jsonResponse['error']["message"];
        logger.f("Exception is below");
        throw HttpException(jsonResponse['error']["message"]);
      }
      logger.i("no error");

      return jsonResponse["choices"][0]["message"]["content"];
    } catch (error) {
      throw Exception('Error: $error');
    }
  }

  Future<String> sendImageToGPT4Vision({
    required File image,
    int maxTokens = 50,
    String model = "gpt-4o",
  }) async {
    final String base64Image = await encodeImage(image);
    logger.i("Image Encoded successfully!");
    logger.e("The Encoded file: $base64Image");

    try {
      final response = await dio.post(
        "$BASE_URL/chat/completions",
        options: Options(
          headers: {
            HttpHeaders.authorizationHeader: 'Bearer $API_KEY',
            HttpHeaders.contentTypeHeader: "application/json",
          },
        ),
        data: jsonEncode({
          'model': model,
          'messages': [
            {
              'role': 'system',
              'content': 'You have to give concise and short answers',
            },
            {
              'role': 'user',
              'content':
                  'GPT, your task is to identify plant health issues with precision. Analyze the following image, detect abnormal conditions like diseases, pests, deficiencies, or decay, and respond strictly with the condition\'s name. If a condition is unrecognizable, reply with "I don\'t know". If the image is not plant-related, say "Please pick another image".',
            },
            {
              'role': 'user',
              'content': 'data:image/jpeg;base64,$base64Image',
              // 'content': {
              //   'type': 'image',
              //   'image': 'data:image/jpeg;base64,$base64Image',
              // }
            }
          ],
          'max_tokens': maxTokens,
        }),
      );

      final jsonResponse = response.data;

      if (jsonResponse['error'] != null) {
        var errorMessage = jsonResponse['error']["message"];
        logger.f("jsonResponse on line 116 error: $errorMessage");
        throw HttpException(jsonResponse['error']["message"]);
      }

      return jsonResponse["choices"][0]["message"]["content"];
    } catch (e) {
      logger.w("Error: $e");
      throw Exception('Error: $e');
    }
  }
}
