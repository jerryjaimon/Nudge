// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'card_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TrackerCardAdapter extends TypeAdapter<TrackerCard> {
  @override
  final int typeId = 0;

  @override
  TrackerCard read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TrackerCard(
      id: fields[0] as String,
      title: fields[1] as String,
      emoji: fields[2] as String,
      type: fields[3] as CardType,
      count: fields[4] as int,
      target: fields[5] as int,
      frequency: fields[6] as Frequency,
      currentStreak: fields[7] as int,
      bestStreak: fields[8] as int,
      lastCompleted: fields[9] as DateTime?,
      history: (fields[10] as List?)?.cast<DateTime>(),
      totalMinutes: fields[11] as int,
      weightHistory: (fields[12] as List?)?.cast<double>(),
      durationSeconds: fields[13] as int,
      metadata: fields[14] as String,
      iconCodePoint: fields[15] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, TrackerCard obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.emoji)
      ..writeByte(15)
      ..write(obj.iconCodePoint)
      ..writeByte(3)
      ..write(obj.type)
      ..writeByte(4)
      ..write(obj.count)
      ..writeByte(5)
      ..write(obj.target)
      ..writeByte(6)
      ..write(obj.frequency)
      ..writeByte(7)
      ..write(obj.currentStreak)
      ..writeByte(8)
      ..write(obj.bestStreak)
      ..writeByte(9)
      ..write(obj.lastCompleted)
      ..writeByte(10)
      ..write(obj.history)
      ..writeByte(11)
      ..write(obj.totalMinutes)
      ..writeByte(12)
      ..write(obj.weightHistory)
      ..writeByte(13)
      ..write(obj.durationSeconds)
      ..writeByte(14)
      ..write(obj.metadata);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrackerCardAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
