package com.example.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.NotificationsActive
import androidx.compose.material.icons.filled.SpeakerPhone
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Divider
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle

@Composable
fun DashboardScreen(viewModel: MainViewModel) {
    val status by viewModel.status.collectAsStateWithLifecycle()
    val voiceEvents by viewModel.firebaseVoiceEvents.collectAsStateWithLifecycle()
    val isVoiceListening by viewModel.isVoiceListening.collectAsStateWithLifecycle()
    val lastTranscript by viewModel.lastVoiceTranscript.collectAsStateWithLifecycle()
    val assistantReply by viewModel.assistantResponseText.collectAsStateWithLifecycle()

    val pendingRequests = voiceEvents.filter { it.kind == "ask" && it.askStatus == "pending" }
    val handledRequests = voiceEvents.filter { it.askStatus == "answered" || it.askStatus == "lost" || it.kind == "speak" }
    val primaryPending = pendingRequests.firstOrNull()

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        item {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(20.dp))
                    .background(
                        Brush.linearGradient(
                            listOf(Color(0xFFF8FAFC), Color(0xFFEFF6FF), Color(0xFFF5F3FF))
                        )
                    )
                    .border(1.dp, UiTokens.BorderColor, RoundedCornerShape(20.dp))
                    .padding(18.dp)
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Box(
                            modifier = Modifier
                                .size(42.dp)
                                .clip(CircleShape)
                                .background(Brush.linearGradient(listOf(UiTokens.PrimaryEmerald, UiTokens.AccentTeal))),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                imageVector = Icons.Default.Mic,
                                contentDescription = "Voice home",
                                tint = Color.White,
                                modifier = Modifier.size(22.dp)
                            )
                        }
                        Spacer(modifier = Modifier.width(12.dp))
                        Column {
                            Text(
                                text = "Voice Home",
                                fontSize = 22.sp,
                                fontWeight = FontWeight.Bold,
                                color = UiTokens.TextDark
                            )
                            Text(
                                text = "ask_to_client and announce_to_client live here first.",
                                fontSize = 12.sp,
                                color = UiTokens.MutedSlate
                            )
                        }
                    }

                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        StatusChip(
                            label = if (isVoiceListening) "Listening" else "Standby",
                            color = if (isVoiceListening) UiTokens.WaveformGreen else UiTokens.MutedSlate
                        )
                        StatusChip(
                            label = status?.whatsappStatus ?: "Waiting for Firebase",
                            color = UiTokens.PrimaryEmerald
                        )
                    }

                    Text(
                        text = assistantReply,
                        fontSize = 14.sp,
                        color = UiTokens.TextDark,
                        fontWeight = FontWeight.Medium,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis
                    )

                    if (lastTranscript.isNotBlank()) {
                        Text(
                            text = "Last transcript: $lastTranscript",
                            fontSize = 12.sp,
                            color = UiTokens.MutedSlate,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                    }
                }
            }
        }

        item {
            Card(
                colors = CardDefaults.cardColors(containerColor = UiTokens.CardOverlayBg),
                border = UiTokens.borderStroke(),
                shape = RoundedCornerShape(16.dp)
            ) {
                Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(
                            imageVector = Icons.Default.NotificationsActive,
                            contentDescription = "Pending voice request",
                            tint = UiTokens.PrimaryEmerald,
                            modifier = Modifier.size(22.dp)
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            text = "Pending voice request",
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Bold,
                            color = UiTokens.TextDark
                        )
                    }

                    Divider(color = UiTokens.BorderColor)

                    if (primaryPending != null) {
                        VoiceRequestCard(
                            request = primaryPending,
                            accent = UiTokens.PrimaryEmerald,
                            trailingLabel = "Pending now"
                        )
                    } else {
                        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                            Text(
                                text = "No pending ask_to_client right now.",
                                fontSize = 14.sp,
                                fontWeight = FontWeight.Medium,
                                color = UiTokens.TextDark
                            )
                            Text(
                                text = "When the selected Firebase profile needs attention, the request appears here first.",
                                fontSize = 12.sp,
                                color = UiTokens.MutedSlate
                            )
                        }
                    }
                }
            }
        }

        item {
            Card(
                colors = CardDefaults.cardColors(containerColor = UiTokens.CardOverlayBg),
                border = UiTokens.borderStroke(),
                shape = RoundedCornerShape(16.dp)
            ) {
                Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(
                            imageVector = Icons.Default.SpeakerPhone,
                            contentDescription = "Recent handled requests",
                            tint = UiTokens.AccentTeal,
                            modifier = Modifier.size(22.dp)
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            text = "Recently handled",
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Bold,
                            color = UiTokens.TextDark
                        )
                        Spacer(modifier = Modifier.weight(1f))
                        Text(
                            text = handledRequests.size.toString(),
                            fontSize = 12.sp,
                            color = UiTokens.MutedSlate,
                            fontWeight = FontWeight.Bold
                        )
                    }

                    Divider(color = UiTokens.BorderColor)

                    if (handledRequests.isEmpty()) {
                        Text(
                            text = "Handled requests will stay here for quick review.",
                            fontSize = 13.sp,
                            color = UiTokens.MutedSlate
                        )
                    } else {
                        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                            handledRequests.take(3).forEach { request ->
                                VoiceRequestCard(
                                    request = request,
                                    accent = UiTokens.AccentTeal,
                                    trailingLabel = request.answeredAt?.let { DateFormatters.shortTime(it) } ?: "Handled"
                                )
                            }
                        }
                    }
                }
            }
        }

        item {
            Card(
                colors = CardDefaults.cardColors(containerColor = UiTokens.CardOverlayBg),
                border = UiTokens.borderStroke(),
                shape = RoundedCornerShape(16.dp)
            ) {
                Row(
                    modifier = Modifier.padding(16.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Box(
                        modifier = Modifier
                            .size(44.dp)
                            .clip(CircleShape)
                            .background(Color(0xFFEFF6FF)),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            imageVector = Icons.Default.Mic,
                            contentDescription = "STT and TTS note",
                            tint = UiTokens.PrimaryEmerald,
                            modifier = Modifier.size(22.dp)
                        )
                    }
                    Spacer(modifier = Modifier.width(12.dp))
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = "STT + TTS are part of the core flow",
                            fontSize = 14.sp,
                            fontWeight = FontWeight.Bold,
                            color = UiTokens.TextDark
                        )
                        Text(
                            text = "The mobile app is the voice interface of the assistant, not a general control panel.",
                            fontSize = 12.sp,
                            color = UiTokens.MutedSlate
                        )
                    }
                }
            }
        }
    }
}
