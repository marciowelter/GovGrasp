function Row({ label, value }) {
    return (
        <div className="grid grid-cols-3 gap-2 py-2 border-b border-gray-100 last:border-0">
            <dt className="text-sm text-gray-500 font-medium">{label}</dt>
            <dd className="col-span-2 text-sm text-gray-900">{value ?? '—'}</dd>
        </div>
    )
}

function fmt(amount, currency) {
    if (amount == null) return null
    return new Intl.NumberFormat('en-GB', { style: 'currency', currency: currency ?? 'GBP', maximumFractionDigits: 0 }).format(amount)
}

function fmtDate(dt) {
    if (!dt) return null
    return new Date(dt).toLocaleDateString('en-GB', { day: '2-digit', month: 'long', year: 'numeric' })
}

const STATUS_COLOR = {
    qualified: 'bg-green-100 text-green-800',
    rejected: 'bg-red-100 text-red-800',
    new: 'bg-yellow-100 text-yellow-800',
}

export default function OpportunityDetail({ opportunity, onClose }) {
    if (!opportunity) return null

    return (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-sm">
            <div className="bg-white rounded-2xl shadow-2xl w-full max-w-2xl max-h-[90vh] flex flex-col">
                {/* Header */}
                <div className="flex items-start justify-between p-6 border-b border-gray-100">
                    <div className="pr-4">
                        <h2 className="text-lg font-semibold text-gray-900 leading-snug">{opportunity.title}</h2>
                        <p className="text-sm text-gray-500 mt-1">{opportunity.buyer_name}</p>
                    </div>
                    <button
                        onClick={onClose}
                        className="text-gray-400 hover:text-gray-700 text-2xl leading-none shrink-0 transition"
                        aria-label="Close"
                    >
                        ×
                    </button>
                </div>

                {/* Body */}
                <div className="overflow-y-auto p-6 space-y-4 flex-1">
                    {/* Badges */}
                    <div className="flex flex-wrap gap-2 mb-2">
                        <span className={`text-xs font-semibold px-3 py-1 rounded-full ${STATUS_COLOR[opportunity.status] ?? 'bg-gray-100 text-gray-700'}`}>
                            {opportunity.status}
                        </span>
                        {opportunity.framework && (
                            <span className="text-xs font-semibold px-3 py-1 rounded-full bg-purple-100 text-purple-800">
                                {opportunity.framework}
                            </span>
                        )}
                        {opportunity.ai_score != null && (
                            <span className="text-xs font-semibold px-3 py-1 rounded-full bg-blue-100 text-blue-800">
                                AI Score: {opportunity.ai_score}/100
                            </span>
                        )}
                    </div>

                    {/* AI Reasoning */}
                    {opportunity.ai_reasoning && (
                        <div className="bg-blue-50 border border-blue-100 rounded-xl p-4">
                            <p className="text-xs font-semibold text-blue-600 uppercase tracking-wide mb-1">AI Analysis</p>
                            <p className="text-sm text-blue-900">{opportunity.ai_reasoning}</p>
                        </div>
                    )}

                    {/* Key details */}
                    <dl>
                        <Row label="OCID" value={<span className="font-mono text-xs">{opportunity.ocid}</span>} />
                        <Row label="Value" value={fmt(opportunity.value_amount, opportunity.value_currency)} />
                        <Row label="Deadline" value={fmtDate(opportunity.deadline)} />
                        <Row label="Published" value={fmtDate(opportunity.published_at)} />
                        <Row label="Source" value={opportunity.source} />
                    </dl>

                    {/* Description */}
                    {opportunity.description && (
                        <div>
                            <p className="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-2">Description</p>
                            <p className="text-sm text-gray-700 leading-relaxed whitespace-pre-wrap">
                                {opportunity.description}
                            </p>
                        </div>
                    )}
                </div>

                {/* Footer */}
                <div className="p-4 border-t border-gray-100 flex justify-end">
                    <button
                        onClick={onClose}
                        className="px-5 py-2 bg-gray-100 hover:bg-gray-200 text-gray-700 rounded-lg text-sm font-medium transition"
                    >
                        Close
                    </button>
                </div>
            </div>
        </div>
    )
}
