---
title: "class-diagram.mermaid"
id: markdown_798285c88467638f6a8dc28635ad6f33_c3ac198ba4d612ee105d3eb54c7230a57505655250320770
kb: 有据-YouJu
folder: "开发文档"
media_type: 7
tags: []
source: ima
exported_at: 2026-11-23T14:52:37.917Z
---
classDiagram
    class User {
      +Int id
      +String? openId
      +String? unionID
      +bindings UserBinding[]
    }
    class UserBinding {
      +Int id
      +Int userId
      +String provider
      +String externalId
      +DateTime boundAt
      +Boolean isPrimary
      +Json? extra
    }
    User "1" --> "0..*" UserBinding : bindings

    class AccountBindingService {
      +listBindings(userId) BindingItem[]
      +bind(userId, provider, externalId) BindingItem
      +unbind(userId, provider) UnbindResult
      -checkOccupied(provider, externalId, userId) boolean
      -maskExternalId(provider, raw) string
    }
    AccountBindingService ..> UserBinding : reads / writes

    class AccountRouter {
      +GET /v1/account/bindings
      +POST /v1/account/bindings
      +DELETE /v1/account/bindings/:provider
    }
    AccountRouter ..> AccountBindingService : calls
    AccountRouter ..> AuthMiddleware : protects

    class BindingItem {
      +Provider provider
      +string externalId
      +string boundAt
      +boolean isPrimary
      +string displayName
      +string status
    }
    AccountBindingService ..> BindingItem : returns

    class AccountBindingPage {
      +BindingItem[] bindings
      +loadBindings() void
      +handleUnbind(provider) void
    }
    class SettingsPage
    class ProfilePage
    class ApiClient {
      +listBindings() BindingItem[]
      +bindAccount(provider, externalId) BindingItem
      +unbindAccount(provider) UnbindResult
    }

    AccountBindingPage ..> ApiClient : calls
    ApiClient ..> AccountRouter : HTTP /v1/account/bindings
    SettingsPage ..> AccountBindingPage : pushUrl
    ProfilePage ..> SettingsPage : pushUrl
