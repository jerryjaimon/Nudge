// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'savings_jar.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SavingsJarAdapter extends TypeAdapter<SavingsJar> {
  @override
  final int typeId = 11;

  @override
  SavingsJar read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SavingsJar(
      categoryId: fields[0] as String,
      balance: fields[1] as double,
      goalAmount: fields[2] as double?,
      lastUpdated: fields[3] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, SavingsJar obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.categoryId)
      ..writeByte(1)
      ..write(obj.balance)
      ..writeByte(2)
      ..write(obj.goalAmount)
      ..writeByte(3)
      ..write(obj.lastUpdated);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavingsJarAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
