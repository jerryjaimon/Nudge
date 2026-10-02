// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'jar_transfer.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class JarTransferAdapter extends TypeAdapter<JarTransfer> {
  @override
  final int typeId = 12;

  @override
  JarTransfer read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return JarTransfer(
      id: fields[0] as String,
      categoryId: fields[1] as String,
      amount: fields[2] as double,
      direction: fields[3] as JarTransferDirection,
      date: fields[4] as DateTime,
      note: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, JarTransfer obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.categoryId)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.direction)
      ..writeByte(4)
      ..write(obj.date)
      ..writeByte(5)
      ..write(obj.note);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JarTransferAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class JarTransferDirectionAdapter extends TypeAdapter<JarTransferDirection> {
  @override
  final int typeId = 13;

  @override
  JarTransferDirection read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return JarTransferDirection.toMonthlyBudget;
      case 1:
        return JarTransferDirection.toExternalSavings;
      default:
        return JarTransferDirection.toMonthlyBudget;
    }
  }

  @override
  void write(BinaryWriter writer, JarTransferDirection obj) {
    switch (obj) {
      case JarTransferDirection.toMonthlyBudget:
        writer.writeByte(0);
        break;
      case JarTransferDirection.toExternalSavings:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JarTransferDirectionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
