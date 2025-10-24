# Bug Fix: UUID Case Sensitivity Issue

## Problem

The app was failing to load user data with error:
```
Error Domain=NSURLErrorDomain Code=-1103 "resource exceeds maximum size"
```

This error was misleading. The actual issue was:
- **Supabase returns UUIDs in UPPERCASE format** (e.g., `380A5369-6266-4A2D-940C-88CB499DC44C`)
- **Your backend API expects lowercase UUIDs** (e.g., `380a5369-6266-4a2d-940c-88cb499dc44c`)
- When the backend received uppercase UUIDs, it returned HTTP 400 with `null`
- iOS URLSession reported this as error -1103 (misleading)

## Root Cause

API test results:
```bash
# Uppercase UUID - FAILS
curl https://api.exobook.ca/api/users/380A5369-6266-4A2D-940C-88CB499DC44C
# Returns: HTTP 400, null

# Lowercase UUID - WORKS
curl https://api.exobook.ca/api/users/380a5369-6266-4a2d-940c-88cb499dc44c
# Returns: HTTP 200, full user JSON
```

## Solution

### 1. Fixed UUID Conversion in `AuthenticationManager.swift`

**loadUserData method:**
```swift
private func loadUserData(userId: String) async {
    // Convert UUID to lowercase for backend API compatibility
    let lowercaseUserId = userId.lowercased()
    currentUser = try await exobookAPI.getUserWithCourses(id: lowercaseUserId)
}
```

**Sign up flow:**
```swift
// Convert UUID to lowercase for backend API compatibility
let userId = response.user.id.uuidString.lowercased()
```

**Fallback user creation:**
```swift
id: session.user.id.uuidString.lowercased()
```

### 2. Updated User Model

Backend returns different field names:
- `program` instead of `programme`
- `username` field (optional)

**Added to User struct:**
```swift
let username: String?
let program: String?  // Backend uses 'program' not 'programme'

// Convenience accessor for compatibility
var programme: String? { program }
```

## Testing

After the fix:
1. ✅ Sign in with existing account works
2. ✅ User data loads successfully
3. ✅ Sign up creates user with lowercase UUID
4. ✅ Google Sign-In will work with lowercase UUIDs

## Backend Considerations

Your backend should ideally be case-insensitive for UUIDs, but for now the iOS app handles the conversion. Consider updating your backend to:

```go
// Example in Go
userId = strings.ToLower(userId)
```

This would make the API more resilient to UUID case variations.

## Affected Files

- `Services/AuthenticationManager.swift` - UUID conversion in 3 places
- `Models/User.swift` - Field name updates to match backend
- `Services/NetworkService.swift` - No changes needed (cache config added but not required)

## Prevention

To avoid similar issues:
1. Always test API endpoints with curl before integrating
2. Use API contract tests or OpenAPI specs
3. Log the actual API request/response in debug mode
4. Backend should normalize UUIDs to lowercase on input
