package app.society.shared

import kotlinx.datetime.LocalDate
import kotlinx.serialization.Serializable
import kotlin.jvm.JvmInline

/** Money is always integer paise; never floating point. */
@Serializable
@JvmInline
value class Paise(val value: Long) : Comparable<Paise> {
    operator fun plus(other: Paise) = Paise(value + other.value)
    operator fun minus(other: Paise) = Paise(value - other.value)
    override fun compareTo(other: Paise) = value.compareTo(other.value)

    /** "1250.50" style, no currency symbol. */
    fun toDecimalString(): String {
        val sign = if (value < 0) "-" else ""
        val abs = if (value < 0) -value else value
        return "$sign${abs / 100}.${(abs % 100).toString().padStart(2, '0')}"
    }

    companion object {
        val ZERO = Paise(0)
        fun ofRupees(rupees: Long) = Paise(rupees * 100)
    }
}

@Serializable
data class BillingMonth(val year: Int, val month: Int) : Comparable<BillingMonth> {
    init {
        require(month in 1..12) { "month must be 1..12, was $month" }
    }

    override fun compareTo(other: BillingMonth) = compareValuesBy(this, other, { it.year }, { it.month })
    override fun toString() = "$year-${month.toString().padStart(2, '0')}"
}

@Serializable
enum class MemberRole { OWNER, TENANT, COMMITTEE, TREASURER, ADMIN }

@Serializable
enum class BillStatus { UNPAID, CLAIMED, PAID }

@Serializable
enum class PaymentMode { UPI, CASH, BANK }

@Serializable
data class Society(
    val id: String,
    val name: String,
    val city: String,
    val upiId: String? = null,
    val upiPayeeName: String? = null,
    val billDueDay: Int = 10,
)

@Serializable
data class Home(
    val id: String,
    val societyId: String,
    val label: String,
    val monthlyAmount: Paise,
)

@Serializable
data class Bill(
    val id: String,
    val societyId: String,
    val homeId: String,
    val month: BillingMonth,
    val amount: Paise,
    val status: BillStatus,
    val dueDate: LocalDate,
    val publicToken: String? = null,
)
