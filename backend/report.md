# FlowerApplication – NoSQL Final Project Report

Course: Advanced Databases (NoSQL)

## Project Overview
FlowerApplication is a full-stack web application for a multi-role flower marketplace with four roles: user, florist, delivery, and admin. The system provides a REST API over MongoDB and a Flutter frontend that consumes the API for authentication, catalog browsing, ordering, and role-specific workflows.

Why this design:
- Multi-role marketplace workflows require role-based access control, so the backend enforces JWT auth and role checks.
- MongoDB is used for flexible catalog and order data while supporting aggregation analytics.

## System Architecture
- Backend: Node.js + Express, MongoDB (Mongoose), JWT auth.
- Frontend: Flutter mobile app consuming REST endpoints.
- API is versioned at `/api/v1` with `/api` as a legacy alias.
- Swagger/OpenAPI documentation is served at `/api-docs`.

Backend flow:
- `backend/src/server.js` loads env, connects to MongoDB, starts HTTP server.
- `backend/src/app.js` mounts middleware, routes, error handlers, and Swagger.
- Routes are grouped by resource under `backend/src/routes/`.

Why this design:
- Clear separation of concerns (routes, models, middleware) improves maintainability.
- Centralized error handling keeps responses consistent.

## Database Schema Description
The data model uses both embedded and referenced documents.

Embedded example (order items inside orders):
- File: `backend/src/models/Order.js`
```js
const orderSchema = new mongoose.Schema({
  userId: { type: String, required: true },
  floristId: { type: String, required: true },
  items: [orderItemSchema],
  totalPrice: { type: Number, required: true }
});
```

Referenced examples:
- `backend/src/models/Flower.js` references `Category` and `User` (florist) via ObjectId.
- `backend/src/models/Favorite.js` references `User` and `Flower`.

Why this design:
- Embedded order items speed up order reads without extra joins.
- Referenced catalog and user data avoid duplication and enable reuse.

## MongoDB Queries and Operators
CRUD is implemented across multiple collections (flowers, categories, cities, orders, users, promotions, etc.).

Advanced update and delete operators:
- File: `backend/src/routes/order.routes.js`
```js
$push  // add new item to order
$pull  // remove item from order
$inc   // adjust order total
$set   // update embedded item fields via positional operator
```
Example:
```js
{ $set: { "items.$.quantity": qty } }
```

Why this design:
- Advanced operators reduce round trips and ensure atomic updates to embedded arrays.

## Aggregation Framework
Multi-stage aggregation is used for florist analytics:
- File: `backend/src/routes/order.routes.js` (`GET /orders/analytics/florist/:floristId`)
- Stages: `$match`, `$facet`, `$group`, `$unwind`, `$addFields`, `$lookup`, `$sort`, `$limit`, `$project`.

Why this design:
- Real business metrics (revenue, status breakdown, top-selling flowers) require aggregation across orders and embedded items.

## Indexing and Optimization Strategy
Compound indexes were added to support frequent queries:
- File: `backend/src/models/Order.js`
```js
orderSchema.index({ floristId: 1, status: 1, createdAt: -1 });
orderSchema.index({ userId: 1, createdAt: -1 });
orderSchema.index({ deliverId: 1, status: 1, createdAt: -1 });
orderSchema.index({ "items.flowerId": 1 });
```
- File: `backend/src/models/Flower.js`
```js
flowerSchema.index({ categoryId: 1, available: 1, price: 1 });
flowerSchema.index({ floristId: 1, available: 1, createdAt: -1 });
flowerSchema.index({ city: 1, available: 1, createdAt: -1 });
```
- Unique compound index in `backend/src/models/Favorite.js` to prevent duplicates.

Why this design:
- These match the most common filters and sort orders (status, role, recency, category/city filters).

## REST API Documentation
- OpenAPI spec: `backend/src/docs/openapi.yaml`
- Swagger UI served at `/api-docs`.

Key endpoints (non-exhaustive):
- Auth: `/auth/register`, `/auth/login`, `/auth/reset-password`
- Catalog: `/categories`, `/cities`, `/flowers`
- Orders: `/orders`, `/orders/user/:userId`, `/orders/analytics/florist/:floristId`
- Admin: `/admin/users`
- Favorites: `/favorites`
- Notifications: `/notifications`

Why this design:
- Resource-oriented endpoints align with REST principles.
- Versioning allows safe future changes.

## Security (Authentication and Authorization)
- JWT verification: `backend/src/middleware/authMiddleware.js`
- Role-based access: `backend/src/middleware/requireRole.js` and `requireAnyRole.js`
- Sensitive routes require auth and role checks (orders, favorites, admin, promotions, notifications, etc.).

Why this design:
- Prevents unauthorized access to user data and admin functions.

## Frontend Requirements
The Flutter frontend integrates with the backend via HTTP requests:
- Login, register, profile update: `application/lib/services/api_service.dart`
- Orders: `application/lib/services/order_service.dart`
- User pages: home, basket, orders, profile, search, florist/admin/deliver dashboards.

Why this design:
- Ensures the project is a complete web application with frontend + backend integration.

## Requirement Mapping (Rubric)

A. MongoDB Implementation – 50 points
- CRUD Operations: Implemented across collections (`flowers`, `orders`, `users`, `categories`, `cities`, `promotions`).
- Data modeling: Embedded order items + referenced catalog/user data.
- Advanced update/delete: `$set`, `$push`, `$pull`, `$inc`, positional operator in `order.routes.js`.
- Aggregation: multi-stage pipeline for florist analytics in `order.routes.js`.
- Indexes: compound indexes in `Order` and `Flower`, unique indexes in `User`, `City`, `Favorite`.

B. Backend Logic and REST API – 30 points
- REST design: versioned API, resource-based routes, consistent HTTP verbs.
- Business logic: order creation, status workflows, florist analytics, favorites, connections.
- Security: JWT auth + role checks on protected routes.
- Code quality: route separation, middleware, centralized error handling.

C. Frontend – 10 points
- Functional pages: home, basket, orders, profile, admin, florist, deliver.
- API integration: real HTTP requests from Flutter.
- Basic usability: structured screens and role dashboards.

D. Documentation – 10 points
- Database documentation: schema + relations described above.
- API documentation: OpenAPI + Swagger.
- Architecture explanation: backend flow + frontend integration described.

## Additional Engineering Features (Bonus)
- Swagger/OpenAPI spec at `backend/src/docs/openapi.yaml`.
- Centralized error handling in `backend/src/middleware/errorHandler.js`.
- API versioning under `/api/v1`.
- Pagination/sorting helpers in `backend/src/utils/query.js`.
- Environment configuration: `backend/.env.example` and `render.yaml`.

## Contribution of Each Student
- Student 1: <Name> – Backend, database design, API, aggregation, indexing, documentation.
- Student 2 (optional): <Name> – Frontend integration, UI screens, testing.

## Project Defense Notes
- Format: live demo, report, code.
- Duration: 15-20 minutes per team.
- Any member can be questioned on any part of the project.

## Repository
- GitHub link: <Insert link>
