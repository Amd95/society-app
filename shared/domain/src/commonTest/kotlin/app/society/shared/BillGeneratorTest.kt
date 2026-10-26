package app.society.shared

import kotlinx.datetime.LocalDate
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class BillGeneratorTest {
    private val april = BillingMonth(2027, 4)

    private fun home(id: String, rupees: Long) =
        Home(id = id, societyId = "s1", label = id.uppercase(), monthlyAmount = Paise.ofRupees(rupees))

    private fun generate(homes: List<Home>, existing: List<Bill> = emptyList()): List<Bill> {
        var n = 0
        return BillGenerator.generate(homes, existing, april, dueDay = 10, newId = { "b${n++}" }, newToken = { "t${n}" })
    }

    @Test
    fun createsOneUnpaidBillPerBillableHome() {
        val bills = generate(listOf(home("a1", 500), home("a2", 500), home("a3", 0)))
        assertEquals(listOf("a1", "a2"), bills.map { it.homeId })
        assertTrue(bills.all { it.status == BillStatus.UNPAID && it.dueDate == LocalDate(2027, 4, 10) })
    }

    @Test
    fun isIdempotentForHomesAlreadyBilled() {
        val first = generate(listOf(home("a1", 500)))
        val second = generate(listOf(home("a1", 500), home("a2", 500)), existing = first)
        assertEquals(listOf("a2"), second.map { it.homeId })
    }

    @Test
    fun clampsDueDayInShortMonths() {
        assertEquals(LocalDate(2027, 2, 28), BillGenerator.dueDateFor(BillingMonth(2027, 2), 31))
        assertEquals(LocalDate(2028, 2, 29), BillGenerator.dueDateFor(BillingMonth(2028, 2), 31))
    }
}
