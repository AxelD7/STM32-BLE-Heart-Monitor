import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';

class Monitor extends StatefulWidget {
  const Monitor({super.key, required this.device});

  final BluetoothDevice device;

  @override
  State<Monitor> createState() => _MonitorState();
}

class EKGPoint {
  final DateTime time;
  final int value;

  EKGPoint(this.time, this.value);
}

class _MonitorState extends State<Monitor> {
  BluetoothConnectionState _connectionState =
      BluetoothConnectionState.disconnected;
  List<BluetoothService> _services = [];
  BluetoothCharacteristic? _characteristic;
  StreamSubscription<List<int>>? _dataSubscription;

  late StreamSubscription<BluetoothConnectionState>
  _connectionStateSubscription;

  ValueNotifier<String> btOutput = ValueNotifier<String>("");
  ValueNotifier<int> hrValue = ValueNotifier<int>(0);
  ValueNotifier<int> spo2Value = ValueNotifier<int>(0);
  ValueNotifier<int> analogValue = ValueNotifier<int>(0);

  List<EKGPoint> _ekgData = [];

  late ChartSeriesController _chartSeriesController;

  bool _isPaused = false;

  @override
  void initState() {
    super.initState();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);

    _connectionStateSubscription = widget.device.connectionState.listen((
      state,
    ) async {
      _connectionState = state;
      if (state == BluetoothConnectionState.connected) {
        await discoverServices();
      } else if (state == BluetoothConnectionState.disconnected) {
        widget.device.connect();
      }
      if (mounted) {
        setState(() {});
      }
    });

    widget.device.connect();
  }

  @override
  void dispose() {
    _connectionStateSubscription.cancel();
    _dataSubscription?.cancel();
    super.dispose();
  }

  Future<void> discoverServices() async {
    _services = await widget.device.discoverServices();

    BluetoothService service = _services.firstWhere(
      (s) => s.uuid.toString() == 'ffe0',
    );

    _characteristic = service.characteristics.firstWhere(
      (c) => c.uuid.toString() == 'ffe1',
    );

    print("Found characteristic: ${_characteristic?.uuid}");

    await _subscribeToCharacteristic();
  }

  Future<void> _subscribeToCharacteristic() async {
    if (_characteristic != null) {
      _dataSubscription = _characteristic!.lastValueStream.listen((value) {
        btOutput.value = String.fromCharCodes(value);
        _splitBTData(btOutput.value);
        print("Received data: $btOutput");
      });

      await _characteristic!.setNotifyValue(true);
    } else {
      print("Characteristic is not available");
    }
  }

  void _splitBTData(String value) {
    List<String> values = [];
    values = value.split(',');
    hrValue.value = int.parse(values[0]);
    spo2Value.value = int.parse(values[1]);
    analogValue.value = int.parse(values[2]);

    _addEKGPoint(analogValue.value);
  }

  void _addEKGPoint(int value) {
    if (_isPaused) return;

    final now = DateTime.now();
    setState(() {
      _ekgData.add(EKGPoint(now, value));

      _ekgData.removeWhere(
        (point) => now.difference(point.time).inMilliseconds > 1500,
      );

      if (_chartSeriesController != null) {
        _chartSeriesController.updateDataSource(
          addedDataIndexes: <int>[_ekgData.length - 1],
          removedDataIndexes: <int>[],
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar(),
      body: monitor(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _isPaused = !_isPaused;
          });
        },
        child: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
        tooltip: _isPaused ? 'Resume' : 'Pause',
      ),
    );
  }

  Widget monitor() {
    final screenWidth = MediaQuery.of(context).size.width;

    return Row(
      children: [
        SizedBox(
          width: screenWidth * 0.3,
          child: Column(
            children: [
              Expanded(
                child: ValueListenableBuilder(
                  valueListenable: hrValue,
                  builder: (context, value, _) {
                    return Container(
                      color: Colors.redAccent,
                      child: Center(
                        child: Text(
                          "Heart Rate: $value",
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Expanded(
                child: ValueListenableBuilder(
                  valueListenable: spo2Value,
                  builder: (context, value, _) {
                    return Container(
                      color: Colors.blueAccent,
                      child: Center(
                        child: Text(
                          "SPo2: $value",
                          style: TextStyle(
                            fontSize: 32, 
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        //EKG Section
        SizedBox(
          width: screenWidth * 0.7,
          child: Container(
            child: SfCartesianChart(
              primaryXAxis: DateTimeAxis(
                intervalType: DateTimeIntervalType.seconds,
                dateFormat: DateFormat.ms(),
                title: AxisTitle(text: "Time"),
              ),
              primaryYAxis: NumericAxis(
                title: AxisTitle(text: "EKG Value"),
                minimum: 500,
                maximum: 3800,
              ),
              series: <LineSeries<EKGPoint, DateTime>>[
                LineSeries<EKGPoint, DateTime>(
                  onRendererCreated: (ChartSeriesController controller) {
                    _chartSeriesController = controller;
                  },
                  dataSource: _ekgData,
                  xValueMapper: (EKGPoint point, _) => point.time,
                  yValueMapper: (EKGPoint point, _) => point.value,
                  color: Colors.green,
                  width: 2,
                  animationDuration: 0,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  AppBar appBar() {
    return AppBar(
      title: Text(
        "Monitor",
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
