# Whisper Backend Integration

This document describes how the current Assistant app should integrate with the existing local Python transcription backend that is already running independently.

## Goal

Keep the current real-time user experience in macOS Speech Recognition, but use the Python backend as the final transcription pass.

The intended UX is:

1. show partial transcripts in real time
2. capture the raw audio for the current spoken turn
3. when the user finishes speaking and auto-submit fires, send the audio to the Python backend
4. wait for the final transcription with punctuation and cleaner structure
5. submit the backend result instead of the rough local transcript

## Backend Base URL

Use the local backend at:

```text
http://127.0.0.1:8000
```

`localhost:8000` is equivalent, but `127.0.0.1:8000` avoids DNS and IPv6 ambiguity.

## Current Backend Contract

The Python backend currently exposes one HTTP transcription endpoint:

```http
POST /transcribe
```

### Request

`multipart/form-data`

Fields:

- `file` required
  - audio file to transcribe
  - safest format is WAV, mono, 16 kHz PCM
- `model` optional
  - model name to use when the backend supports multiple models
  - if omitted, the backend uses its default model

### Response

The backend returns JSON with the transcription result.

Expected fields:

- `text`
  - final transcription string
- `segments`
  - array of time-aligned segments
  - each segment typically includes `start`, `end`, `text`
- `language`
  - detected or resolved language identifier

### Error behavior

On failure, the backend returns a non-2xx response with a JSON error payload.
The Assistant should treat this as a recoverable failure and fall back to the local transcript if needed.

## Recommended App Flow

### 1. Keep local real-time recognition

The Assistant should continue using macOS Speech Recognition for:

- partial transcript updates
- immediate visual feedback
- low-latency user experience

This keeps the UI responsive while the user is speaking.

### 2. Preserve the raw audio for the current turn

The current implementation only needs the recognized text.
To use the backend for final polishing, the app must also retain the final audio buffer for the last turn or segment.

The safest approach is to export the captured audio as:

- mono
- 16 kHz
- WAV

### 3. Trigger final transcription after the user stops speaking

When the app decides that the turn ended:

- keep the local partial transcript visible
- stop the local listening session
- send the stored audio file to `POST /transcribe`
- wait for the backend response

### 4. Replace the provisional text with the backend result

When the backend returns:

- replace the rough local transcript with `text`
- preserve the existing auto-submit flow
- submit the backend text into the current voice/prompt pipeline

### 5. Fallback behavior

If the backend is unavailable, times out, or returns an error:

- keep the local transcript
- continue the existing auto-submit behavior
- log the failure for observability

## Files To Change In Ai Personal Assistant LocalHub

These are the files that will likely need changes on the Assistant side only.

### Voice capture and finalization

- [`Server/Sources/Services/Voice/VoiceAssistant.swift`](/Users/DevData/victorwads/GitRepos/Personal/AssistantMCPServer/Server/Sources/Services/Voice/VoiceAssistant.swift)
  - add a way to preserve the final audio buffer or export the current turn to WAV
  - keep the current partial transcript behavior unchanged
  - expose a final-audio artifact that the UI can submit to the backend

### Hands-free prompt flow

- [`Server/Sources/Views/ClientVoicePromptWindow.swift`](/Users/DevData/victorwads/GitRepos/Personal/AssistantMCPServer/Server/Sources/Views/ClientVoicePromptWindow.swift)
  - wait for backend final transcription before calling submit
  - keep the current debounce and auto-submit behavior

- [`Server/Sources/Views/ClientVoiceHandsFreeWindow.swift`](/Users/DevData/victorwads/GitRepos/Personal/AssistantMCPServer/Server/Sources/Views/ClientVoiceHandsFreeWindow.swift)
  - same change as above for the pending-client-ask flow

### Orchestration

- [`Server/Sources/App/AppModel.swift`](/Users/DevData/victorwads/GitRepos/Personal/AssistantMCPServer/Server/Sources/App/AppModel.swift)
  - centralize the backend call and fallback behavior
  - keep the voice state updates consistent

### Settings

- [`Server/Sources/Features/Settings/SettingsScreen.swift`](/Users/DevData/victorwads/GitRepos/Personal/AssistantMCPServer/Server/Sources/Features/Settings/SettingsScreen.swift)
  - add a configurable transcription backend URL if we do not want to hardcode `127.0.0.1:8000`
  - otherwise, keep the backend URL as a fixed local default

### New helper files recommended

These are not mandatory, but they are the cleanest place to add the integration:

- `Server/Sources/Services/Voice/WhisperTranscriptionClient.swift`
  - HTTP client for `POST /transcribe`
  - multipart upload
  - timeout handling
  - JSON decoding

- `Server/Sources/Features/Voice/Settings/TranscriptionBackendSettingsModel.swift`
  - optional URL/port settings
  - useful if the backend path may vary per machine

## Suggested Implementation Order

1. Add an HTTP client for the transcription backend.
2. Extend voice capture to retain/export the final turn audio.
3. Wire the final auto-submit path to call the backend first.
4. Use the backend `text` as the final submitted prompt.
5. Add fallback and logging.
6. Only after that, consider making the backend URL configurable.

## Important Constraints

- Do not change the Python backend unless the HTTP contract must expand.
- Do not block the real-time partial transcript path.
- Do not make the UI wait for the backend before showing the local partial text.
- Do not submit the local rough transcript if the backend final result is available in time.

## Summary

The Assistant app should treat the Python backend as the final transcription authority and macOS Speech Recognition as the live UX layer.

That gives us:

- real-time feedback from macOS
- cleaner final text from the Python backend
- a single final auto-submit behavior for the user
