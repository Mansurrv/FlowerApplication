// models/order.dart
class Order {
  final String? id;
  final String? userId;
  final String? floristId;
  final String? deliverId;
  final String status;
  final double totalPrice;
  final String city;
  final String? orderNumber;
  final String? deliveryAddress;
  final List<OrderItem> items;
  final DateTime? createdAt;

  Order({
    this.id,
    this.userId,
    this.floristId,
    this.deliverId,
    required this.status,
    required this.totalPrice,
    required this.city,
    this.orderNumber,
    this.deliveryAddress,
    required this.items,
    this.createdAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['_id'],
      userId: json['userId'] is Map ? json['userId']['_id'] : json['userId'],
      floristId: json['floristId'] is Map
          ? json['floristId']['_id']
          : json['floristId'],
      deliverId: json['deliverId'] is Map
          ? json['deliverId']['_id']
          : json['deliverId'],
      status: json['status'] ?? 'pending',
      totalPrice: (json['totalPrice'] ?? 0).toDouble(),
      city: json['city'] ?? '',
      orderNumber: json['orderNumber'],
      deliveryAddress: json['deliveryAddress'],
      items:
          (json['items'] as List<dynamic>?)
              ?.map((item) => OrderItem.fromJson(item))
              .toList() ??
          [],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      if (userId != null) 'userId': userId,
      if (floristId != null) 'floristId': floristId,
      if (deliverId != null) 'deliverId': deliverId,
      'status': status,
      'totalPrice': totalPrice,
      'city': city,
      if (orderNumber != null) 'orderNumber': orderNumber,
      if (deliveryAddress != null) 'deliveryAddress': deliveryAddress,
      'items': items.map((item) => item.toJson()).toList(),
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    };
  }
}

class OrderItem {
  final String flowerId;
  final int quantity;
  final double price;

  OrderItem({
    required this.flowerId,
    required this.quantity,
    required this.price,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      flowerId: json['flowerId'],
      quantity: json['quantity'] ?? 1,
      price: (json['price'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'flowerId': flowerId, 'quantity': quantity, 'price': price};
  }
}
