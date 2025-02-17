import 'package:flutter/material.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NFC Access Control',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  String? _registeredCardId;
  bool _isProcessing = false;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _loadRegisteredCard();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 10),
    );
    _animation = Tween(begin: 0.0, end: 1.0).animate(_animationController);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadRegisteredCard() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _registeredCardId = prefs.getString('registeredCardId');
    });
  }

  Future<void> _registerCard() async {
    try {
      var availability = await FlutterNfcKit.nfcAvailability;
      if (availability != NFCAvailability.available) {
        throw Exception('NFC not available');
      }

      var tag = await FlutterNfcKit.poll();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('registeredCardId', tag.id);
      setState(() {
        _registeredCardId = tag.id;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Card registered successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      await FlutterNfcKit.finish();
    }
  }

  Future<void> _openDoor() async {
    if (_registeredCardId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No card registered')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });
    _animationController.reset();
    _animationController.forward();

    try {
      var availability = await FlutterNfcKit.nfcAvailability;
      if (availability != NFCAvailability.available) {
        throw Exception('NFC not available');
      }

      // 카드 리더기와 통신
      NFCTag readerTag = await FlutterNfcKit.poll(
        timeout: Duration(seconds: 10),
        iosMultipleTagMessage: "Multiple tags found!",
        iosAlertMessage: "Hold your phone near the door reader",
      );

      // 카드 리더기에 등록된 카드 ID 전송
      await FlutterNfcKit.transceive("AUTHENTICATE $_registeredCardId");

      // 응답 확인
      String response = await FlutterNfcKit.transceive("GET_STATUS");
      
      if (response == "DOOR_OPEN") {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Door opened successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open door. Please try again.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      await FlutterNfcKit.finish();
      setState(() {
        _isProcessing = false;
      });
      _animationController.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('NFC Access Control')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
              onPressed: _registerCard,
              child: Text('Register Card'),
            ),
            SizedBox(height: 20),
            Text('Registered Card ID: ${_registeredCardId ?? "None"}'),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isProcessing ? null : _openDoor,
              child: Text('Open Door'),
            ),
            SizedBox(height: 20),
            if (_isProcessing)
              Column(
                children: [
                  CircularProgressIndicator(
                    value: _animation.value,
                  ),
                  SizedBox(height: 10),
                  AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return Text(
                        'Processing: ${(_animation.value * 100).toInt()}%',
                        style: TextStyle(fontSize: 16),
                      );
                    },
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
