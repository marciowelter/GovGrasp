const STATUS_BADGE = {
    qualified: 'bg-green-100 text-green-800',
    rejected: 'bg-red-100  text-red-800',
    new: 'bg-yellow-100 text-yellow-800',
}

function ScoreBar({ score }) {
    if (score == null) return <span className="text-gray-400 text-xs">N/A</span>
    const color = score >= 70 ? 'bg-green-500' : score >= 40 ? 'bg-yellow-500' : 'bg-red-500'
    return (
        <div className="flex items-center gap-2">
            <div className="w-20 bg-gray-200 rounded-full h-2">
                <div className={`${color} h-2 rounded-full`} style={{ width: `${score}%` }} />
            </div>
            <span className="text-xs text-gray-600">{score}</span>
        </div>
    )
}

function fmt(amount, currency) {
    if (amount == null) return '—'
    return new Intl.NumberFormat('en-GB', { style: 'currency', currency: currency ?? 'GBP', maximumFractionDigits: 0 }).format(amount)
}

function fmtDate(dt) {
    if (!dt) return '—'
    return new Date(dt).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' })
}

export default function OpportunityTable({ opportunities, loading, onSelect, pagination, onPageChange }) {
    if (loading) {
        return (
            <div className="space-y-3">
                {Array.from({ length: 6 }).map((_, i) => (
                    <div key={i} className="h-14 bg-gray-200 rounded-lg animate-pulse" />
                ))}
            </div>
        )
    }

    if (!opportunities?.length) {
        return (
            <div className="text-center py-16 text-gray-400">
                <p className="text-4xl mb-2">📭</p>
                <p className="text-lg">No opportunities found.</p>
                <p className="text-sm mt-1">Try adjusting your filters or trigger a new pipeline run.</p>
            </div>
        )
    }

    return (
        <div>
            <div className="overflow-x-auto rounded-xl border border-gray-200 shadow-sm">
                <table className="w-full text-sm">
                    <thead className="bg-gray-100 text-gray-600 uppercase text-xs tracking-wide">
                        <tr>
                            <th className="px-4 py-3 text-left">Title</th>
                            <th className="px-4 py-3 text-left">Buyer</th>
                            <th className="px-4 py-3 text-left">Value</th>
                            <th className="px-4 py-3 text-left">Framework</th>
                            <th className="px-4 py-3 text-left">AI Score</th>
                            <th className="px-4 py-3 text-left">Deadline</th>
                            <th className="px-4 py-3 text-left">Status</th>
                        </tr>
                    </thead>
                    <tbody className="divide-y divide-gray-100">
                        {opportunities.map((opp) => (
                            <tr
                                key={opp.id}
                                onClick={() => onSelect(opp)}
                                className="hover:bg-blue-50 cursor-pointer transition-colors"
                            >
                                <td className="px-4 py-3 font-medium max-w-xs truncate" title={opp.title}>{opp.title}</td>
                                <td className="px-4 py-3 text-gray-600 max-w-[160px] truncate">{opp.buyer_name ?? '—'}</td>
                                <td className="px-4 py-3 whitespace-nowrap">{fmt(opp.value_amount, opp.value_currency)}</td>
                                <td className="px-4 py-3">
                                    {opp.framework
                                        ? <span className="bg-purple-100 text-purple-800 text-xs px-2 py-0.5 rounded-full">{opp.framework}</span>
                                        : <span className="text-gray-400">—</span>}
                                </td>
                                <td className="px-4 py-3"><ScoreBar score={opp.ai_score} /></td>
                                <td className="px-4 py-3 whitespace-nowrap text-gray-600">{fmtDate(opp.deadline)}</td>
                                <td className="px-4 py-3">
                                    <span className={`text-xs font-semibold px-2 py-0.5 rounded-full ${STATUS_BADGE[opp.status] ?? 'bg-gray-100 text-gray-700'}`}>
                                        {opp.status}
                                    </span>
                                </td>
                            </tr>
                        ))}
                    </tbody>
                </table>
            </div>

            {pagination && pagination.last_page > 1 && (
                <div className="flex justify-between items-center mt-4 text-sm text-gray-600">
                    <span>
                        Showing {pagination.from}–{pagination.to} of {pagination.total}
                    </span>
                    <div className="flex gap-2">
                        <button
                            onClick={() => onPageChange(pagination.current_page - 1)}
                            disabled={pagination.current_page === 1}
                            className="px-3 py-1.5 rounded border border-gray-300 disabled:opacity-40 hover:bg-gray-100 transition"
                        >
                            ← Prev
                        </button>
                        <button
                            onClick={() => onPageChange(pagination.current_page + 1)}
                            disabled={pagination.current_page === pagination.last_page}
                            className="px-3 py-1.5 rounded border border-gray-300 disabled:opacity-40 hover:bg-gray-100 transition"
                        >
                            Next →
                        </button>
                    </div>
                </div>
            )}
        </div>
    )
}
