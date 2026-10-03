// Консольная симуляция ядра: dart run tool/sim.dart [сид] [минуты] [rich]
// ignore_for_file: avoid_print
import 'package:iskra/core/sim.dart';

void main(List<String> args) {
  final seed = args.isNotEmpty ? int.parse(args[0]) : 1;
  final minutes = args.length > 1 ? double.parse(args[1]) : 120.0;
  final sw = Stopwatch()..start();
  final r = runSim(seed: seed, minutes: minutes, rich: args.length > 2 && args[2] == 'rich');
  print('seed $seed: $minutes min (${sw.elapsedMilliseconds} ms), $r');
}
