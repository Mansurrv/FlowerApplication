// models/basket_item.dart - UPDATE THIS FILE
import 'package:flutter/foundation.dart';

class BasketItem {
  final String id;
  final String flowerId;
  final String name;
  final double price;
  final int quantity;
  final String imageUrl;
  final String? floristId; // Make it optional for now
  final String? floristName;

  BasketItem({
    required this.id,
    required this.flowerId,
    required this.name,
    required this.price,
    required this.quantity,
    required this.imageUrl,
    this.floristId, // Optional for now
    this.floristName,
  });

  double get total => price * quantity;

  BasketItem copyWith({
    String? id,
    String? flowerId,
    String? name,
    double? price,
    int? quantity,
    String? imageUrl,
    String? floristId,
    String? floristName,
  }) {
    return BasketItem(
      id: id ?? this.id,
      flowerId: flowerId ?? this.flowerId,
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      imageUrl: imageUrl ?? this.imageUrl,
      floristId: floristId ?? this.floristId,
      floristName: floristName ?? this.floristName,
    );
  }

  @override
  String toString() {
    return 'BasketItem{name: $name, flowerId: $flowerId, floristId: $floristId}';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'flowerId': flowerId,
      'name': name,
      'price': price,
      'quantity': quantity,
      'imageUrl': imageUrl,
      'floristId': floristId,
      'floristName': floristName,
    };
  }

  static BasketItem fromJson(Map<String, dynamic> json) {
    return BasketItem(
      id: json['id']?.toString() ?? '',
      flowerId: json['flowerId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      price: (json['price'] is num)
          ? (json['price'] as num).toDouble()
          : double.tryParse(json['price']?.toString() ?? '') ?? 0.0,
      quantity: (json['quantity'] is num)
          ? (json['quantity'] as num).toInt()
          : int.tryParse(json['quantity']?.toString() ?? '') ?? 0,
      imageUrl: json['imageUrl']?.toString() ?? '',
      floristId: json['floristId']?.toString(),
      floristName: json['floristName']?.toString(),
    );
  }
}
