package app.society.shared

/** Builds a `upi://pay` deep link for the society's UPI ID (payments go straight to the society). */
object UpiLink {

    fun build(payeeVpa: String, payeeName: String, amount: Paise, note: String): String {
        require(payeeVpa.contains('@')) { "Invalid UPI ID: $payeeVpa" }
        require(amount > Paise.ZERO) { "Amount must be positive" }
        return buildString {
            append("upi://pay")
            append("?pa=").append(encode(payeeVpa))
            append("&pn=").append(encode(payeeName))
            append("&am=").append(amount.toDecimalString())
            append("&cu=INR")
            append("&tn=").append(encode(note))
        }
    }

    private fun encode(value: String): String = buildString {
        for (byte in value.encodeToByteArray()) {
            val c = byte.toInt() and 0xFF
            val unreserved = c.toChar() in 'A'..'Z' || c.toChar() in 'a'..'z' ||
                c.toChar() in '0'..'9' || c.toChar() in "-_.~@"
            if (unreserved) {
                append(c.toChar())
            } else {
                append('%')
                append(HEX[c shr 4])
                append(HEX[c and 0xF])
            }
        }
    }

    private const val HEX = "0123456789ABCDEF"
}
