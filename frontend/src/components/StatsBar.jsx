export default function StatsBar({ stats, loading }) {
    const cards = [
        { label: 'Total', value: stats?.total ?? '—', color: 'bg-blue-50 text-blue-700 border-blue-200' },
        { label: 'Qualified', value: stats?.qualified ?? '—', color: 'bg-green-50 text-green-700 border-green-200' },
        { label: 'Rejected', value: stats?.rejected ?? '—', color: 'bg-red-50 text-red-700 border-red-200' },
        { label: 'Today', value: stats?.today ?? '—', color: 'bg-yellow-50 text-yellow-700 border-yellow-200' },
    ]

    return (
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
            {cards.map((c) => (
                <div
                    key={c.label}
                    className={`rounded-xl border p-4 text-center shadow-sm ${c.color} ${loading ? 'animate-pulse' : ''}`}
                >
                    <p className="text-3xl font-bold">{c.value}</p>
                    <p className="text-sm font-medium mt-1">{c.label}</p>
                </div>
            ))}
        </div>
    )
}
