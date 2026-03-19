import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../theme/app_theme.dart';

/// Tela de scanner de código de barras / QR Code
/// Usa o pacote mobile_scanner já presente no pubspec.
class BarcodeScannerScreen extends StatefulWidget {
  final void Function(String code) onDetected;
  const BarcodeScannerScreen({super.key, required this.onDetected});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  late MobileScannerController _ctrl;
  bool _detected = false;

  @override
  void initState() {
    super.initState();
    _ctrl = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_detected) return; // evita disparo duplo
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null || code.isEmpty) return;
    _detected = true;
    widget.onDetected(code);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Escanear Código',
            style: TextStyle(color: AppColors.textHigh)),
        iconTheme: const IconThemeData(color: AppColors.textHigh),
        actions: [
          IconButton(
            icon: ValueListenableBuilder<MobileScannerState>(
              valueListenable: _ctrl,
              builder: (_, state, __) => Icon(
                state.torchState == TorchState.on
                    ? Icons.flash_on
                    : Icons.flash_off,
                color: state.torchState == TorchState.on
                    ? AppColors.neonAmber
                    : AppColors.textLow,
              ),
            ),
            onPressed: () => _ctrl.toggleTorch(),
            tooltip: 'Lanterna',
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _ctrl,
            onDetect: _onDetect,
          ),
          // Overlay de mira
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(
                    color: AppColors.neonCyan, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          // Legenda
          Positioned(
            bottom: 40,
            left: 0, right: 0,
            child: const Text(
              'Aponte para o código de barras ou QR Code',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white70, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
