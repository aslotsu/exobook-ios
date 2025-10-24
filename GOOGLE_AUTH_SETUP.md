# Google Authentication Setup for Exobook

## ✅ What's Already Implemented

Your iOS app now has Google Sign-In support! Here's what was added:

### 1. **AuthenticationManager** (`Services/AuthenticationManager.swift`)
- Added `signInWithGoogle()` method that initiates OAuth flow
- Uses Supabase's built-in Google OAuth provider

### 2. **AuthenticationView** (`Views/Auth/AuthenticationView.swift`)
- Added "Continue with Google" button with nice styling
- Integrated with AuthenticationManager for seamless auth flow

### 3. **Deep Link Handling** (`ExobookApp.swift`)
- Already configured to handle OAuth callback URLs
- Uses `exobook://auth-callback` as redirect URI

## 🔧 Required Supabase Configuration

To make Google Sign-In work, you need to configure it in your Supabase dashboard:

### Step 1: Enable Google Provider in Supabase

1. Go to your Supabase Dashboard: https://supabase.com/dashboard
2. Select your project: `wszlgkiivyejlykntghj`
3. Navigate to **Authentication** → **Providers**
4. Find **Google** in the list and click to configure

### Step 2: Create Google OAuth Credentials

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing one
3. Navigate to **APIs & Services** → **Credentials**
4. Click **Create Credentials** → **OAuth client ID**
5. Select **iOS** as application type
6. Add your bundle identifier: `ca.exobook.Exobook`
7. Add your iOS URL scheme: `exobook`
8. Create another OAuth client for **Web application** (for Supabase)
9. Copy the **Client ID** and **Client Secret**

### Step 3: Configure Google Provider in Supabase

Back in Supabase dashboard:

1. Paste the **Client ID** from Google Cloud Console
2. Paste the **Client Secret** from Google Cloud Console
3. Under **Authorized redirect URIs**, add:
   ```
   https://wszlgkiivyejlykntghj.supabase.co/auth/v1/callback
   ```
4. Click **Save**

### Step 4: Add URL Scheme to Xcode

Since the project uses auto-generated Info.plist, you need to add the URL scheme via Xcode:

1. Open `Exobook.xcodeproj` in Xcode
2. Select the **Exobook** target
3. Go to the **Info** tab
4. Scroll to **URL Types** section
5. Click **+** to add a new URL type
6. Set:
   - **Identifier**: `ca.exobook.Exobook.auth`
   - **URL Schemes**: `exobook`
   - **Role**: `Editor`

## 🧪 Testing Google Sign-In

### In Simulator/Device:

1. Build and run the app
2. On the authentication screen, tap **"Continue with Google"**
3. You'll be redirected to Google's sign-in page in Safari
4. After signing in, you'll be redirected back to the app
5. The app will create a user account in your backend if it's a new user

### What Happens Behind the Scenes:

1. `signInWithGoogle()` opens Safari with Google OAuth URL
2. User signs in with Google
3. Google redirects to `exobook://auth-callback` with auth token
4. `onOpenURL` handler in `ExobookApp.swift` captures the token
5. Supabase authenticates the user
6. `AuthenticationManager` loads user data from your backend
7. User is automatically signed in

## 🔒 Security Notes

- OAuth tokens are handled securely by Supabase
- Never commit your Google Client Secret to Git
- The redirect URI must match exactly in all places:
  - Google Cloud Console
  - Supabase Dashboard
  - Your iOS app code

## 🐛 Troubleshooting

### "Invalid redirect URI"
- Check that `exobook://auth-callback` is added to Xcode URL schemes
- Verify the URL scheme in Google Cloud Console

### "OAuth provider not configured"
- Ensure Google provider is enabled in Supabase Dashboard
- Verify Client ID and Secret are correct

### "User creation failed"
- Check your backend API is running
- Verify the `createUser` endpoint is accessible
- Check backend logs for errors

## 📱 User Flow

```
Sign In Screen
     ↓ [Tap "Continue with Google"]
Google Sign-In (Safari)
     ↓ [User authenticates]
Redirect to App (exobook://)
     ↓ [Token exchange]
Supabase Auth ✓
     ↓ [Load user data]
Backend API (api.exobook.ca)
     ↓ [User data loaded]
Main App Screen ✓
```

## ✨ Next Steps

Once Google OAuth is configured in Supabase:

1. Test the flow end-to-end
2. Consider adding Apple Sign-In (similar process)
3. Add error handling for failed OAuth flows
4. Implement profile picture sync from Google

## 📝 Additional Configuration (Optional)

### Customize Google Button Appearance:
Edit `Views/Auth/AuthenticationView.swift` around line 92-108

### Change Redirect URI:
Update both:
- `AuthenticationManager.swift` line 147
- Supabase Dashboard
- Google Cloud Console

### Add More OAuth Providers:
Supabase supports: Apple, GitHub, GitLab, Bitbucket, etc.
Follow similar pattern in `AuthenticationManager`
