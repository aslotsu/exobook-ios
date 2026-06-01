# Real-time Chat Implementation with Pusher

## Overview
The Exobook iOS app now includes real-time chat messaging using Pusher WebSockets. Messages are delivered instantly to all chat participants without requiring manual refresh.

## Architecture

### Backend
- **Service**: Chat backend running at `chats.linkio.ca`
- **Pusher Configuration**:
  - Key: `a77d99a67f8892897039`
  - Cluster: `mt1`
- **Channel Format**: `chats-{chatID}`
- **Event Name**: `new-message`

### iOS Implementation

#### Components

1. **ExobookChatService** (`Services/ExobookChatService.swift`)
   - Manages Pusher client connection
   - Handles chat-specific channel subscriptions
   - Processes incoming message events
   - Maintains active subscription state

2. **ChatThreadView** (`Views/ChatThreadView.swift`)
   - Subscribes to real-time messages when view appears
   - Unsubscribes when view disappears
   - Implements optimistic UI updates for sent messages

## How It Works

### Message Flow

1. **Sending a Message**:
   ```swift
   // User types and sends message
   → Message added optimistically to UI (instant feedback)
   → API call to backend POST /chats/{chatId}/messages/new
   → Backend saves to DynamoDB
   → Backend triggers Pusher event on channel "chats-{chatId}"
   ```

2. **Receiving a Message**:
   ```swift
   // Pusher event received
   → handleNewMessage() parses event data
   → Filters out own messages (already shown optimistically)
   → Creates Message object
   → Calls onEvent callback
   → ChatThreadView appends to messages array
   → UI updates automatically
   ```

### Event Payload
```json
{
  "chat_id": "uuid-string",
  "message_id": "uuid-string",
  "user_id": "sender-user-id",
  "username": "sender-name",
  "words": "message text",
  "images": [],
  "files": [],
  "timestamp": 1234567890000
}
```

### Key Features

#### Optimistic Updates
When you send a message:
- Message appears immediately in your UI
- No waiting for server response
- Better UX with instant feedback

#### Duplicate Prevention
Messages from the current user are filtered out when received via Pusher since they're already displayed optimistically.

#### Automatic Cleanup
Subscriptions are automatically cleaned up when:
- User navigates away from chat
- User switches to different chat
- App terminates

## Code Examples

### Subscribing to Messages
```swift
try? await service.subscribeToMessages(chatId: chat.id) { newMessage in
    Task { await appendMessage(newMessage) }
}
```

### Unsubscribing
```swift
service.unsubscribe(chatId: chat.id)
```

### Sending Messages
```swift
// Optimistic update
let optimisticMessage = Message(...)
await appendMessage(optimisticMessage)

// Send to backend
try await service.sendMessage(chatId: chat.id, text: text)
```

## Testing

### Console Logs
Look for these log messages:

- `🔴 Chat Pusher configured for user: {userId}` - Pusher initialized
- `📡 Subscribing to messages for chat: {chatId}` - Channel subscription started
- `✅ Subscribed to channel: chats-{chatId}` - Subscription successful
- `💬 Received new message: {messageId} from {userId}` - New message received
- `⏩ Skipping own message: {messageId}` - Own message filtered
- `🔇 Unsubscribing from chat: {chatId}` - Cleanup on navigation away

### Manual Testing Steps

1. **Single Device Test**:
   - Open chat
   - Send message
   - Should appear instantly
   - Check console for Pusher logs

2. **Multi-Device Test**:
   - Open same chat on two devices
   - Send message from Device A
   - Message should appear on Device B within 1-2 seconds
   - Verify correct sender/timestamp

3. **Connection Test**:
   - Open chat (subscribe)
   - Navigate away (unsubscribe)
   - Navigate back (re-subscribe)
   - Send/receive messages still work

## Troubleshooting

### Messages Not Appearing

1. **Check Pusher Connection**:
   - Look for connection logs in console
   - Verify key/cluster configuration

2. **Check Channel Name**:
   - Format must be exactly `chats-{chatId}`
   - chatId must match backend format (UUID)

3. **Check Event Binding**:
   - Event name is `new-message` (with hyphen)
   - Case-sensitive

### Duplicate Messages

If you see duplicate messages:
- Check that optimistic message has same ID as backend response
- Verify filtering logic for own messages

### Memory Leaks

- Ensure `[weak self]` in Pusher callbacks
- Verify unsubscribe is called on view disappear
- Check activeSubscriptions dictionary is cleaned up

## Future Enhancements

Potential improvements:
- [ ] Typing indicators
- [ ] Read receipts
- [ ] Message delivery status
- [ ] Offline message queueing
- [ ] Reconnection handling
- [ ] Message reactions via Pusher events
- [ ] User online/offline status

## Related Files

- `Services/ExobookChatService.swift` - Main Pusher integration
- `Views/ChatThreadView.swift` - UI and subscription management
- `Models/ChatService.swift` - Protocol definition
- `Services/RealtimeManager.swift` - Global Pusher manager (used for posts/likes)

## Backend Reference

Backend code: `/Users/alfredlotsu/GolandProjects/workspace/exobook/chats/`
- `services/notification_service.go` - Pusher event triggering
- `handlers/message_handlers.go` - Message creation and notifications
