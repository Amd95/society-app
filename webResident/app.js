// Resident bill page. No framework, no login: the link carries a per-bill token (?t=...).
// All data access goes through two public Supabase RPCs: get_public_bill and claim_payment.
(function () {
  "use strict";

  var STR = {
    hi: { loading: "लोड हो रहा है…", invalid: "यह लिंक मान्य नहीं है। कृपया कमेटी से नया लिंक मांगें।",
      due: "देय तिथि", home: "घर", pay: "UPI से भुगतान करें", paid: "मैंने भुगतान कर दिया",
      utr: "UTR / रेफरेंस नंबर (वैकल्पिक)", claimed: "धन्यवाद! कोषाध्यक्ष भुगतान की पुष्टि करेंगे।",
      status: { unpaid: "बकाया", claimed: "पुष्टि बाकी", paid: "भुगतान हो गया" },
      ledger: "सोसाइटी का हिसाब", collected: "कुल जमा", spent: "कुल खर्च", balance: "शेष",
      expenses: "हाल के खर्च", upiId: "UPI ID", error: "कुछ गड़बड़ हुई। दोबारा कोशिश करें." },
    en: { loading: "Loading…", invalid: "This link is not valid. Please ask the committee for a new one.",
      due: "Due", home: "Home", pay: "Pay with UPI", paid: "I've paid",
      utr: "UTR / reference number (optional)", claimed: "Thank you! The treasurer will confirm your payment.",
      status: { unpaid: "Unpaid", claimed: "Awaiting confirmation", paid: "Paid" },
      ledger: "Society accounts", collected: "Collected", spent: "Spent", balance: "Balance",
      expenses: "Recent expenses", upiId: "UPI ID", error: "Something went wrong. Please try again." }
  };

  var cfg = window.SOCIETY_CONFIG || {};
  var root = document.getElementById("root");
  var token = new URLSearchParams(location.search).get("t");
  var lang = (function () { try { return localStorage.getItem("lang"); } catch (e) { return null; } })();
  var data = null;

  function t() { return STR[lang] || STR.hi; }
  function esc(s) { var d = document.createElement("div"); d.textContent = s == null ? "" : String(s); return d.innerHTML; }
  function card(inner) { return "<div class='card'>" + inner + "</div>"; }
  function rupees(paise) {
    var n = Number(paise), sign = n < 0 ? "-" : "", a = Math.abs(n);
    return sign + "₹" + Math.floor(a / 100).toLocaleString("en-IN") + (a % 100 ? "." + String(a % 100).padStart(2, "0") : "");
  }

  function rpc(name, body) {
    return fetch(cfg.supabaseUrl + "/rest/v1/rpc/" + name, {
      method: "POST",
      headers: { "Content-Type": "application/json", apikey: cfg.anonKey, Authorization: "Bearer " + cfg.anonKey },
      body: JSON.stringify(body)
    }).then(function (r) {
      if (!r.ok) throw new Error("rpc " + name + " " + r.status);
      return r.status === 204 ? null : r.json();
    });
  }

  // Mirrors UpiLink in shared/domain: payments go straight to the society's UPI ID.
  function upiLink(d) {
    var q = [["pa", d.society.upi_id], ["pn", d.society.payee_name],
             ["am", (d.bill.amount_paise / 100).toFixed(2)], ["cu", "INR"],
             ["tn", "Maintenance " + d.bill.month.slice(0, 7) + " " + d.bill.home_label]];
    return "upi://pay?" + q.map(function (p) { return p[0] + "=" + encodeURIComponent(p[1]).replace(/%40/g, "@"); }).join("&");
  }

  function render() {
    var s = t();
    document.documentElement.lang = lang || "hi";
    document.getElementById("lang").textContent = (lang === "en") ? "हिं" : "EN";
    if (!data) { root.innerHTML = card(esc(s.loading)); return; }
    if (data === "invalid") { root.innerHTML = card(esc(s.invalid)); return; }
    if (data === "error") { root.innerHTML = card(esc(s.error)); return; }

    var b = data.bill, so = data.society, l = data.ledger;
    var html = "<div class='card'><h1>" + esc(so.name) + "</h1>" +
      "<div class='mut'>" + esc(s.home) + " " + esc(b.home_label) + " · " + esc(b.month.slice(0, 7)) + "</div>" +
      "<div class='amt'>" + rupees(b.amount_paise) + "</div>" +
      "<span class='badge'>" + esc(s.status[b.status]) + "</span> <span class='mut'>" + esc(s.due) + " " + esc(b.due_date) + "</span>";

    if (b.status === "unpaid" && so.upi_id) {
      html += "<a class='btn' href='" + esc(upiLink(data)) + "'>" + esc(s.pay) + "</a>" +
        "<div class='mut' style='margin-top:8px'>" + esc(s.upiId) + ": " + esc(so.upi_id) + "</div>" +
        "<input id='utr' inputmode='numeric' maxlength='32' placeholder='" + esc(s.utr) + "'>" +
        "<button class='btn alt' id='claim' type='button'>" + esc(s.paid) + "</button>";
    } else if (b.status === "claimed") {
      html += "<p>" + esc(s.claimed) + "</p>";
    }

    html += "</div><div class='card'><h2>" + esc(s.ledger) + "</h2><table>" +
      "<tr><td>" + esc(s.collected) + "</td><td>" + rupees(l.collected_paise) + "</td></tr>" +
      "<tr><td>" + esc(s.spent) + "</td><td>" + rupees(l.spent_paise) + "</td></tr>" +
      "<tr><td><b>" + esc(s.balance) + "</b></td><td><b>" + rupees(l.collected_paise - l.spent_paise) + "</b></td></tr></table></div>";

    if (data.expenses.length) {
      html += "<div class='card'><h2>" + esc(s.expenses) + "</h2><table>" + data.expenses.map(function (e) {
        return "<tr><td>" + esc(e.spent_on) + " · " + esc(e.category) + (e.vendor ? " (" + esc(e.vendor) + ")" : "") +
          "</td><td>" + rupees(e.amount_paise) + "</td></tr>";
      }).join("") + "</table></div>";
    }
    root.innerHTML = html;

    var claim = document.getElementById("claim");
    if (claim) claim.addEventListener("click", function () {
      claim.disabled = true;
      rpc("claim_payment", { p_token: token, p_utr: document.getElementById("utr").value || null })
        .then(load).catch(function () { claim.disabled = false; alert(s.error); });
    });
  }

  function load() {
    if (!token || !cfg.supabaseUrl) { data = "invalid"; return render(); }
    rpc("get_public_bill", { p_token: token })
      .then(function (d) { data = d || "invalid"; if (!lang && d) lang = d.society.language; render(); })
      .catch(function () { data = "error"; render(); });
  }

  document.getElementById("lang").addEventListener("click", function () {
    lang = lang === "en" ? "hi" : "en";
    try { localStorage.setItem("lang", lang); } catch (e) { /* storage may be blocked */ }
    render();
  });

  render();
  load();
})();
