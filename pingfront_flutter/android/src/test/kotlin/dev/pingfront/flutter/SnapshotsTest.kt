package dev.pingfront.flutter

import dev.pingfront.PingFront
import dev.pingfront.model.Message
import java.io.File
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

/** Messages cross to Dart as the wire's JSON: the SDK's own serializers, checked against the protocol fixtures. */
class SnapshotsTest {
    private val json = Json { ignoreUnknownKeys = true }

    /** The `valid` values of the shared fixture sdk/Message.json (the working directory is android/). */
    private fun fixtureMessages(): List<Message> {
        val file = File("../test/fixtures/sdk/Message.json")
        val cases = json.parseToJsonElement(file.readText()).jsonObject.getValue("valid").jsonArray
        return cases.map { json.decodeFromJsonElement(Message.serializer(), it.jsonObject.getValue("value")) }
    }

    @Test
    fun everyFixtureMessageSurvivesTheTripToDart() {
        val messages = fixtureMessages()
        assertEquals(6, messages.size)
        val text = Snapshots.messagesJson(messages)
        val again = json.decodeFromString(ListSerializer(Message.serializer()), text)
        assertEquals(messages, again)
        // Dates are ISO-8601 text, as on the wire; nulls are left out, as the server leaves them out.
        assertTrue(text.contains("\"createdAt\":\"2026-10-30T18:00:00.000Z\""), text)
        assertTrue(!text.contains("null"), text)
    }

    @Test
    fun theConversationBeforeConfigureMapsToTheDefaults() {
        val m = Snapshots.conversation(PingFront.conversation.state.value, draft = "half a thought", insertion = null)
        assertEquals("idle", m.phase)
        assertNull(m.failureCode)
        assertEquals("[]", m.messagesJson)
        assertEquals("[]", m.teamJson)
        assertTrue(m.canSend)
        assertNull(m.closedReason)
        assertEquals("open", m.status)
        assertEquals("stopped", m.live)
        assertNull(m.typingIsAi)
        assertEquals("half a thought", m.draft)
        assertTrue(m.coolingDown.isEmpty())
        assertTrue(m.awaitingApproval.isEmpty())
    }

    @Test
    fun aCardIsFoundOnlyByItsMessageAndCardIds() {
        assertNull(Snapshots.card(PingFront.conversation.state.value, "msg_1", "c1"))
    }
}
