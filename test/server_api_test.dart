import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:subbi/apis/server_api.dart';

class MockClient extends Mock implements HttpClient {}

class MockRequest extends Mock implements HttpClientRequest {}

class MockResponse extends Mock implements HttpClientResponse {}

class MockCookie extends Mock implements Cookie {}

main() {

  var mockClient = MockClient();
  
  ServerApi.host = 'test';
  ServerApi.port = 80;
  ServerApi.client = mockClient;

  ServerApi api = ServerApi.instance();

  group('login', () {

    var mockSessionCookie = MockCookie();
    when(mockSessionCookie.name).thenReturn('session');
    when(mockSessionCookie.value).thenReturn('testValue');

    var mockLoginRes = MockResponse();
    when(mockLoginRes.cookies).thenReturn([mockSessionCookie]);

    var mockLoginReq = MockRequest();
    when(mockLoginReq.close()).thenAnswer((_) async=> mockLoginRes);

    when(mockClient.postUrl(Uri.http(ServerApi.host, '/login'))).thenAnswer((_) async=> mockLoginReq);

    test('Existing user', () async {
     
      when(mockLoginRes.statusCode).thenReturn(200);

      expect(await api.signIn(userToken: ''), true);
      expect(api.sessionCookie.value, 'testValue');
    
    });

    test('Non existing user', () async {

      when(mockLoginRes.statusCode).thenReturn(404);

      expect(await api.signIn(userToken: ''), false);
      expect(api.sessionCookie.value, 'testValue');

    });

  });

}