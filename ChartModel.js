function shift(day, amount) {
    var date = new Date(day + "T12:00:00Z")
    date.setUTCDate(date.getUTCDate() + amount)
    return date.toISOString().slice(0, 10)
}

function compact(value) {
    if (value === null || value === undefined) return "–"
    if (value >= 1e9) return (value / 1e9).toFixed(2).replace(/\.?0+$/, "") + "B"
    if (value >= 1e6) return (value / 1e6).toFixed(1).replace(/\.0$/, "") + "M"
    if (value >= 1e3) return (value / 1e3).toFixed(1).replace(/\.0$/, "") + "k"
    return String(value)
}

function week(days, end) {
    var lookup = {}
    for (var i = 0; i < days.length; i++) lookup[days[i].date] = days[i].tokens
    var rows = [], total = 0, count = 0, peak = 0
    for (var offset = -6; offset <= 0; offset++) {
        var day = shift(end, offset)
        var tokens = Object.prototype.hasOwnProperty.call(lookup, day) ? lookup[day] : null
        rows.push({date: day, tokens: tokens})
        if (tokens !== null) { total += tokens; count++; peak = Math.max(peak, tokens) }
    }
    return {rows: rows, total: total, count: count, peak: peak}
}
