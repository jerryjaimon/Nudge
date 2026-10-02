// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'category_budget.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CategoryBudgetAdapter extends TypeAdapter<CategoryBudget> {
  @override
  final int typeId = 10;

  @override
  CategoryBudget read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CategoryBudget(
      id: fields[0] as String,
      name: fields[1] as String,
      icon: fields[2] as String,
      colourHex: fields[3] as String,
      monthlyLimit: fields[4] as double,
      rolloverEnabled: fields[5] as bool,
      createdAt: fields[6] as DateTime,
      isArchived: fields[7] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, CategoryBudget obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.icon)
      ..writeByte(3)
      ..write(obj.colourHex)
      ..writeByte(4)
      ..write(obj.monthlyLimit)
      ..writeByte(5)
      ..write(obj.rolloverEnabled)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.isArchived);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryBudgetAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
