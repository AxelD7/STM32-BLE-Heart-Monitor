import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:heart_mon_app/pages/monitor.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<BluetoothDevice> _discoveredDevices = [];

  void initState() {
    super.initState();
  }

  void startScan() async {
    setState(() {
      _discoveredDevices.clear();
    });

    print("in scan pressed!");
    if (await FlutterBluePlus.isSupported == false) {
      print("Bluetooth not supported");
      return;
    }

    await FlutterBluePlus.adapterState
        .where((state) => state == BluetoothAdapterState.on)
        .first;

    var subscription = FlutterBluePlus.onScanResults.listen((results) {
      if (results.isNotEmpty) {
        print("in results not empty!");
        for (ScanResult result in results) {
          final newDevice = result.device;

          print(
            "DEVICE FOUND! ID: ${newDevice.remoteId} NAME: ${newDevice.platformName}",
          );
          final previouslyFound = _discoveredDevices.any(
            (d) => d.remoteId == newDevice.remoteId,
          );
          if (!previouslyFound) {
            setState(() {
              _discoveredDevices.add(newDevice);
            });
          }
        }
      }
    });

    FlutterBluePlus.cancelWhenScanComplete(subscription);

    await FlutterBluePlus.startScan(timeout: Duration(seconds: 5));

    await FlutterBluePlus.isScanning.where((val) => val == false).first;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar(),
      body:
          _discoveredDevices.isEmpty
              ? const Center(child: Text("no devices found!"))
              : ListView.builder(
                itemCount: _discoveredDevices.length,
                itemBuilder: (context, index) {
                  final device = _discoveredDevices[index];
                  return Card(
                    child: ListTile(
                      title: Text(device.platformName),
                      subtitle: Text(device.remoteId.str),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => Monitor(device: device),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: startScan,
        label: const Text("Scan!"),
        backgroundColor: Colors.blue,
        extendedTextStyle: TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  AppBar appBar() {
    return AppBar(
      title: Text(
        "Scan for a Device",
        style: TextStyle(
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: Colors.white,
    );
  }
}
