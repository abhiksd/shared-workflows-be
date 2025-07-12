# 🎯 Nginx Ingress Regular Expression Routing Guide

This guide explains how to use advanced regular expression routing patterns in your Helm chart for sophisticated traffic routing to different backend services.

## 🚀 Overview

The ingress configuration now supports advanced regex-based routing that allows you to:
- Route requests to different microservices based on URL patterns
- Extract parameters from URLs and pass them to backend services
- Implement API versioning routing
- Handle geographic and time-based routing
- Support A/B testing and feature flag routing

## 📁 Environment-Specific Implementations

| Environment | Complexity | Use Case |
|-------------|------------|----------|
| **Development** | Basic | Simple service routing for development |
| **Staging** | Moderate | Production-like routing with testing features |
| **Production** | Advanced | Complex microservice routing with performance optimization |

## 🔧 Development Environment Patterns

### Basic Service Routing
```yaml
annotations:
  nginx.ingress.kubernetes.io/use-regex: "true"
  nginx.ingress.kubernetes.io/server-snippet: |
    # Route specific API endpoints to different services
    location ~* ^/api/v1/users/(.*)$ {
      proxy_pass http://shared-app-users:8080/api/v1/users/$1;
    }
    location ~* ^/api/v1/orders/(.*)$ {
      proxy_pass http://shared-app-orders:8080/api/v1/orders/$1;
    }
    location ~* ^/api/v1/products/(.*)$ {
      proxy_pass http://shared-app-products:8080/api/v1/products/$1;
    }

paths:
  # User service
  - path: /api/v1/users
    pathType: Prefix
    serviceName: shared-app-users
    servicePort: 8080
  - path: /api/v1/users/.*
    pathType: ImplementationSpecific
    serviceName: shared-app-users
    servicePort: 8080
```

### URL Examples:
- `http://shared-app-dev.yourdomain.com/api/v1/users` → `shared-app-users:8080`
- `http://shared-app-dev.yourdomain.com/api/v1/users/123` → `shared-app-users:8080`
- `http://shared-app-dev.yourdomain.com/api/v1/orders/456` → `shared-app-orders:8080`
- `http://shared-app-dev.yourdomain.com/api/v1/products/abc` → `shared-app-products:8080`

## 🧪 Staging Environment Patterns

### Advanced Resource Routing with Parameters
```yaml
annotations:
  nginx.ingress.kubernetes.io/server-snippet: |
    # User routing with ID extraction
    location ~* ^/api/v1/users/([0-9]+)/?(.*)$ {
      proxy_pass http://shared-app-users:8080/users/$1/$2;
    }
    
    # Order items with nested routing
    location ~* ^/api/v1/orders/([0-9]+)/items/?(.*)$ {
      proxy_pass http://shared-app-orders:8080/orders/$1/items/$2;
    }
    
    # Product category routing
    location ~* ^/api/v1/products/category/([a-zA-Z0-9-]+)/?(.*)$ {
      proxy_pass http://shared-app-products:8080/products/category/$1/$2;
    }
    
    # Search with type specification
    location ~* ^/api/v1/search/([a-zA-Z]+)/?(.*)$ {
      proxy_pass http://shared-app-search:8080/search/$1/$2;
    }
    
    # Date-based reports
    location ~* ^/api/v1/reports/([0-9]{4})/([0-9]{2})/?(.*)$ {
      proxy_pass http://shared-app-reports:8080/reports/$1/$2/$3;
    }

paths:
  # User with ID validation
  - path: /api/v1/users/[0-9]+
    pathType: ImplementationSpecific
    serviceName: shared-app-users
    servicePort: 8080
  
  # Category-based products
  - path: /api/v1/products/category/[a-zA-Z0-9-]+
    pathType: ImplementationSpecific
    serviceName: shared-app-products
    servicePort: 8080
  
  # Year/Month reports
  - path: /api/v1/reports/[0-9]{4}/[0-9]{2}
    pathType: ImplementationSpecific
    serviceName: shared-app-reports
    servicePort: 8080
```

### URL Examples:
- `http://shared-app-staging.yourdomain.com/api/v1/users/123` → `shared-app-users:8080/users/123/`
- `http://shared-app-staging.yourdomain.com/api/v1/users/123/profile` → `shared-app-users:8080/users/123/profile`
- `http://shared-app-staging.yourdomain.com/api/v1/orders/456/items` → `shared-app-orders:8080/orders/456/items/`
- `http://shared-app-staging.yourdomain.com/api/v1/products/category/electronics` → `shared-app-products:8080/products/category/electronics/`
- `http://shared-app-staging.yourdomain.com/api/v1/reports/2023/12` → `shared-app-reports:8080/reports/2023/12/`

## 🏭 Production Environment Patterns

### Enterprise-Grade Routing with Multiple Domains

#### API Domain (`api.yourdomain.com`)
```yaml
annotations:
  nginx.ingress.kubernetes.io/server-snippet: |
    # API versioning with microservice routing
    location ~* ^/api/v([0-9]+)/users/([0-9]+)/?(.*)$ {
      proxy_pass http://shared-app-users-v$1:8080/users/$2/$3;
      add_header X-Service-Version "v$1";
    }
    
    # Payment processing with order context
    location ~* ^/api/v([0-9]+)/orders/([0-9]+)/payment/?(.*)$ {
      proxy_pass http://shared-app-payments:8080/orders/$2/payment/$3;
      add_header X-Service "payments";
    }
    
    # Inventory management with product context
    location ~* ^/api/v([0-9]+)/products/([a-zA-Z0-9-]+)/inventory/?(.*)$ {
      proxy_pass http://shared-app-inventory:8080/products/$2/inventory/$3;
      add_header X-Service "inventory";
    }
    
    # Geographic routing based on country codes
    location ~* ^/api/v([0-9]+)/geo/([A-Z]{2})/(.*)$ {
      proxy_pass http://shared-app-geo-$2:8080/api/v$1/$3;
      add_header X-Country "$2";
    }
    
    # Time-based reporting with full date validation
    location ~* ^/api/v([0-9]+)/reports/([0-9]{4})-([0-9]{2})-([0-9]{2})/?(.*)$ {
      proxy_pass http://shared-app-reports:8080/reports/$2/$3/$4/$5;
      add_header X-Report-Date "$2-$3-$4";
    }
    
    # Feature flag routing
    location ~* ^/api/v([0-9]+)/features/([a-zA-Z0-9_-]+)/?(.*)$ {
      proxy_pass http://shared-app-features:8080/features/$2/$3;
      add_header X-Feature "$2";
    }
    
    # A/B testing routing
    location ~* ^/api/v([0-9]+)/experiments/([a-zA-Z0-9_-]+)/?(.*)$ {
      proxy_pass http://shared-app-experiments:8080/experiments/$2/$3;
      add_header X-Experiment "$2";
    }
```

#### Web Domain (`shared-app.yourdomain.com`)
```yaml
annotations:
  nginx.ingress.kubernetes.io/server-snippet: |
    # Static assets with optimized caching
    location ~* ^/static/(css|js|img)/.*\.(css|js|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
      proxy_pass http://shared-app-cdn:80;
      expires 1y;
      add_header Cache-Control "public, immutable";
      add_header X-Cache-Status "HIT-STATIC";
    }
```

### Production URL Examples:

#### API Versioning:
- `http://api.yourdomain.com/api/v1/users/123` → `shared-app-users-v1:8080/users/123/`
- `http://api.yourdomain.com/api/v2/users/123` → `shared-app-users-v2:8080/users/123/`

#### Payment Processing:
- `http://api.yourdomain.com/api/v1/orders/456/payment` → `shared-app-payments:8080/orders/456/payment/`
- `http://api.yourdomain.com/api/v1/orders/456/payment/confirm` → `shared-app-payments:8080/orders/456/payment/confirm`

#### Geographic Routing:
- `http://api.yourdomain.com/api/v1/geo/US/stores` → `shared-app-geo-US:8080/api/v1/stores`
- `http://api.yourdomain.com/api/v1/geo/CA/stores` → `shared-app-geo-CA:8080/api/v1/stores`

#### Date-Based Reports:
- `http://api.yourdomain.com/api/v1/reports/2023-12-25` → `shared-app-reports:8080/reports/2023/12/25/`
- `http://api.yourdomain.com/api/v1/reports/2023-12-25/sales` → `shared-app-reports:8080/reports/2023/12/25/sales`

#### Feature Flags:
- `http://api.yourdomain.com/api/v1/features/new-checkout` → `shared-app-features:8080/features/new-checkout/`
- `http://api.yourdomain.com/api/v1/experiments/ab-test-1` → `shared-app-experiments:8080/experiments/ab-test-1/`

## 📝 Regex Pattern Reference

### Common Patterns

| Pattern | Description | Example |
|---------|-------------|---------|
| `[0-9]+` | One or more digits | `123`, `456789` |
| `[a-zA-Z]+` | One or more letters | `users`, `Products` |
| `[a-zA-Z0-9-]+` | Letters, numbers, hyphens | `product-abc`, `user123` |
| `[a-zA-Z0-9_-]+` | Letters, numbers, underscores, hyphens | `feature_flag`, `ab-test-1` |
| `[A-Z]{2}` | Exactly 2 uppercase letters | `US`, `CA`, `UK` |
| `[0-9]{4}` | Exactly 4 digits | `2023`, `1999` |
| `[0-9]{2}` | Exactly 2 digits | `01`, `12`, `31` |
| `(.*)` | Capture everything | Any remaining path |
| `/?(.*)` | Optional slash + capture | `/path` or `path` |

### Advanced Patterns

| Pattern | Description | Example |
|---------|-------------|---------|
| `^/api/v([0-9]+)/(.*)$` | API versioning | `/api/v1/users` |
| `^/([a-z]+)/([0-9]+)/?(.*)$` | Resource with ID | `/users/123/profile` |
| `^/products/category/([a-zA-Z0-9-]+)` | Category routing | `/products/category/electronics` |
| `^/reports/([0-9]{4})-([0-9]{2})-([0-9]{2})` | Date routing | `/reports/2023-12-25` |
| `\.(css\|js\|png\|jpg)$` | File extension matching | `.css`, `.js`, `.png` |

## 🔄 Path Type Reference

| PathType | Use Case | Nginx Behavior |
|----------|----------|----------------|
| `Prefix` | Simple prefix matching | Exact prefix match |
| `ImplementationSpecific` | Regex patterns | Nginx regex processing |
| `Exact` | Exact path matching | Must match exactly |

## 🎯 Service Routing Examples

### Microservice Architecture

```yaml
# Users Service
- path: /api/v1/users
  pathType: Prefix
  serviceName: shared-app-users
  servicePort: 8080
- path: /api/v1/users/[0-9]+
  pathType: ImplementationSpecific
  serviceName: shared-app-users
  servicePort: 8080

# Orders Service
- path: /api/v1/orders
  pathType: Prefix
  serviceName: shared-app-orders
  servicePort: 8080
- path: /api/v1/orders/[0-9]+/payment
  pathType: ImplementationSpecific
  serviceName: shared-app-payments
  servicePort: 8080

# Products Service
- path: /api/v1/products
  pathType: Prefix
  serviceName: shared-app-products
  servicePort: 8080
- path: /api/v1/products/[a-zA-Z0-9-]+/inventory
  pathType: ImplementationSpecific
  serviceName: shared-app-inventory
  servicePort: 8080
```

### Frontend Applications

```yaml
# Static Assets (CDN)
- path: /static/.*\.(css|js|png|jpg|jpeg|gif|ico|svg)$
  pathType: ImplementationSpecific
  serviceName: shared-app-cdn
  servicePort: 80

# Web Application
- path: /app
  pathType: Prefix
  serviceName: shared-app-frontend
  servicePort: 80

# Admin Panel
- path: /admin
  pathType: Prefix
  serviceName: shared-app-admin
  servicePort: 8080
```

## ⚡ Performance Optimization

### Caching Headers
```yaml
nginx.ingress.kubernetes.io/server-snippet: |
  # Long-term caching for static assets
  location ~* ^/static/.*\.(css|js|png|jpg|jpeg|gif|ico|svg|woff|woff2)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
    add_header X-Cache-Status "HIT-STATIC";
  }
  
  # Short-term caching for API responses
  location ~* ^/api/v1/products {
    expires 5m;
    add_header Cache-Control "public, max-age=300";
  }
```

### Response Headers
```yaml
nginx.ingress.kubernetes.io/configuration-snippet: |
  # Security headers
  more_set_headers "X-Frame-Options: DENY";
  more_set_headers "X-Content-Type-Options: nosniff";
  more_set_headers "X-XSS-Protection: 1; mode=block";
  
  # Service identification
  more_set_headers "X-Environment: production";
  more_set_headers "X-Service-Version: v1.0.0";
```

## 🛠️ Testing and Debugging

### Test Commands

```bash
# Test user service routing
curl -v http://api.yourdomain.com/api/v1/users/123

# Test with headers to see routing
curl -v -H "Host: api.yourdomain.com" http://your-ingress-ip/api/v1/users/123

# Test geographic routing
curl -v http://api.yourdomain.com/api/v1/geo/US/stores

# Test date-based reports
curl -v http://api.yourdomain.com/api/v1/reports/2023-12-25/sales
```

### Debug Headers

The configuration adds debug headers to help trace routing:
- `X-Service-Version`: Shows API version used
- `X-Service`: Shows which service handled the request
- `X-Country`: Shows country code for geo routing
- `X-Report-Date`: Shows parsed date for reports
- `X-Feature`: Shows feature flag name
- `X-Experiment`: Shows experiment name

## 📋 Best Practices

### 1. Order Matters
Place more specific patterns before general ones:
```yaml
paths:
  # Specific patterns first
  - path: /api/v1/users/[0-9]+/profile
    pathType: ImplementationSpecific
  # General patterns later
  - path: /api/v1/users/[0-9]+
    pathType: ImplementationSpecific
  # Prefix patterns last
  - path: /api/v1/users
    pathType: Prefix
```

### 2. Use Meaningful Service Names
```yaml
# Good
serviceName: shared-app-users-v1
serviceName: shared-app-payments
serviceName: shared-app-inventory

# Avoid
serviceName: service1
serviceName: backend
serviceName: api
```

### 3. Include Fallbacks
```yaml
# Always include a default fallback
- path: /
  pathType: Prefix
  serviceName: shared-app
  servicePort: 8080
```

### 4. Validate Regex Patterns
Test your regex patterns before deploying:
```bash
# Test regex pattern matching
echo "/api/v1/users/123/profile" | grep -E "^/api/v1/users/[0-9]+/.*$"
```

## 🚨 Common Pitfalls

### 1. Greedy Matching
```yaml
# Problem: Too greedy
- path: /api/.*
  pathType: ImplementationSpecific

# Solution: Be specific
- path: /api/v1/users/.*
  pathType: ImplementationSpecific
```

### 2. Missing Escapes
```yaml
# Problem: Unescaped dots
- path: /static/.*.(css|js)$

# Solution: Escape properly
- path: /static/.*\.(css|js)$
```

### 3. Wrong Order
```yaml
# Problem: General pattern first
- path: /api/.*
- path: /api/v1/users/[0-9]+

# Solution: Specific first
- path: /api/v1/users/[0-9]+
- path: /api/.*
```

## 🔄 Migration Guide

### From Simple to Regex Routing

1. **Add regex annotation:**
```yaml
annotations:
  nginx.ingress.kubernetes.io/use-regex: "true"
```

2. **Update path types:**
```yaml
# Before
pathType: Prefix

# After
pathType: ImplementationSpecific
```

3. **Add service routing:**
```yaml
# Before
- path: /api
  pathType: Prefix

# After
- path: /api/v1/users/.*
  pathType: ImplementationSpecific
  serviceName: shared-app-users
  servicePort: 8080
```

## 📚 Additional Resources

- [Nginx Ingress Controller Annotations](https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/annotations/)
- [Nginx Location Directive](http://nginx.org/en/docs/http/ngx_http_core_module.html#location)
- [Regular Expression Testing](https://regex101.com/)
- [Kubernetes Ingress Documentation](https://kubernetes.io/docs/concepts/services-networking/ingress/)

---

**Ready to route!** 🚀 Your ingress now supports sophisticated regex-based routing to multiple backend services with production-grade patterns.