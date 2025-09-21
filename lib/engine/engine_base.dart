import 'dart:async';

// Base classes for engine communication

abstract class EngineMessage {
  final String raw;
  const EngineMessage(this.raw);
}

class InfoMessage extends EngineMessage {
  const InfoMessage(super.raw);
}

class BestMoveMessage extends EngineMessage {
  final String bestMove;
  const BestMoveMessage(this.bestMove, String raw) : super(raw);
}

class ErrorMessage extends EngineMessage {
  const ErrorMessage(super.raw);
}

class ReadyMessage extends EngineMessage {
  const ReadyMessage(super.raw);
}

class UciOkMessage extends EngineMessage {
  const UciOkMessage(super.raw);
}

class UcciOkMessage extends EngineMessage {
  const UcciOkMessage(super.raw);
}

// Abstract engine interface
abstract class IEngine {
  Future<void> start();
  Future<void> stop();
  void send(String cmd);
  Stream<EngineMessage> get messages;
  Future<void> setMultiPV(int n); // 1..3
  Future<void> newGame();
  Future<void> setPosition(String fen, List<String> moves);
  Future<void> go({int? depth, int? movetimeMs});

  // Engine identification
  String get name;
  String get protocol; // "UCI" or "UCCI"
}

// Engine configuration
class EngineConfig {
  final String name;
  final String executablePath;
  final String protocol;
  final Map<String, String> options;

  const EngineConfig({
    required this.name,
    required this.executablePath,
    required this.protocol,
    this.options = const {},
  });
}

// Common engine configurations
class EngineConfigs {
  static const pikafish = EngineConfig(
    name: 'Pikafish',
    executablePath: 'engines/pikafish/win/pikafish.exe',
    protocol: 'UCI',
  );

  static const eleeye = EngineConfig(
    name: 'EleEye',
    executablePath: 'engines/eleeye/win/eleeye.exe',
    protocol: 'UCCI',
  );

  static List<EngineConfig> get all => [pikafish, eleeye];
}
