import { useCallback, useEffect, useState } from 'react'
import { getOpportunities, getOpportunity, getStats, getWorkerStatus } from './api/client'
import OpportunityDetail from './components/OpportunityDetail'
import OpportunityTable from './components/OpportunityTable'
import StatsBar from './components/StatsBar'
import WorkerStatus from './components/WorkerStatus'

const STATUS_OPTIONS = ['', 'qualified', 'rejected', 'new']

export default function App() {
    const [opportunities, setOpportunities] = useState([])
    const [pagination, setPagination] = useState(null)
    const [stats, setStats] = useState(null)
    const [workerStatus, setWorkerStatus] = useState(null)
    const [selected, setSelected] = useState(null)
    const [loadingList, setLoadingList] = useState(false)
    const [loadingStats, setLoadingStats] = useState(false)

    // Filters
    const [search, setSearch] = useState('')
    const [status, setStatus] = useState('')
    const [framework, setFramework] = useState('')
    const [page, setPage] = useState(1)

    const fetchStats = useCallback(async () => {
        setLoadingStats(true)
        try {
            const [statsRes, workerRes] = await Promise.all([getStats(), getWorkerStatus()])
            setStats(statsRes.data)
            setWorkerStatus(workerRes.data)
        } catch {
            // silently ignore — API may not be reachable yet
        } finally {
            setLoadingStats(false)
        }
    }, [])

    const fetchList = useCallback(async () => {
        setLoadingList(true)
        try {
            const params = { page, per_page: 20 }
            if (search) params.search = search
            if (status) params.status = status
            if (framework) params.framework = framework

            const res = await getOpportunities(params)
            const { data, ...meta } = res.data
            setOpportunities(data)
            setPagination(meta)
        } catch {
            // silently ignore
        } finally {
            setLoadingList(false)
        }
    }, [page, search, status, framework])

    // On filter change, reset to page 1
    useEffect(() => { setPage(1) }, [search, status, framework])

    useEffect(() => { fetchStats() }, [fetchStats])
    useEffect(() => { fetchList() }, [fetchList])

    // Poll worker status every 10 s
    useEffect(() => {
        const id = setInterval(fetchStats, 10_000)
        return () => clearInterval(id)
    }, [fetchStats])

    async function handleSelect(opp) {
        try {
            const res = await getOpportunity(opp.id)
            setSelected(res.data)
        } catch {
            setSelected(opp)
        }
    }

    return (
        <div className="min-h-screen bg-gray-50">
            {/* Header */}
            <header className="bg-white border-b border-gray-200 shadow-sm sticky top-0 z-10">
                <div className="max-w-7xl mx-auto px-4 sm:px-6 py-4 flex flex-col sm:flex-row sm:items-center justify-between gap-3">
                    <div>
                        <h1 className="text-xl font-bold text-gray-900">🏛️ GovGrasp</h1>
                        <p className="text-xs text-gray-500">UK Government Procurement Intelligence</p>
                    </div>
                    <WorkerStatus workerStatus={workerStatus} onTriggered={() => { fetchStats(); setTimeout(fetchList, 3000) }} />
                </div>
            </header>

            <main className="max-w-7xl mx-auto px-4 sm:px-6 py-8">
                {/* Stats */}
                <StatsBar stats={stats} loading={loadingStats} />

                {/* Filter bar */}
                <div className="flex flex-col sm:flex-row gap-3 mb-5">
                    <input
                        type="search"
                        placeholder="Search title, buyer, description…"
                        value={search}
                        onChange={(e) => setSearch(e.target.value)}
                        className="flex-1 border border-gray-300 rounded-lg px-4 py-2 text-sm shadow-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                    />

                    <select
                        value={status}
                        onChange={(e) => setStatus(e.target.value)}
                        className="border border-gray-300 rounded-lg px-3 py-2 text-sm shadow-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                    >
                        <option value="">All statuses</option>
                        {STATUS_OPTIONS.filter(Boolean).map((s) => (
                            <option key={s} value={s}>{s.charAt(0).toUpperCase() + s.slice(1)}</option>
                        ))}
                    </select>

                    {stats?.frameworks?.length > 0 && (
                        <select
                            value={framework}
                            onChange={(e) => setFramework(e.target.value)}
                            className="border border-gray-300 rounded-lg px-3 py-2 text-sm shadow-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                        >
                            <option value="">All frameworks</option>
                            {stats.frameworks.map((f) => (
                                <option key={f} value={f}>{f}</option>
                            ))}
                        </select>
                    )}

                    <button
                        onClick={() => { setSearch(''); setStatus(''); setFramework(''); setPage(1) }}
                        className="text-sm text-gray-500 hover:text-gray-800 px-3 py-2 rounded-lg border border-gray-200 hover:bg-gray-100 transition"
                    >
                        Clear
                    </button>
                </div>

                {/* Table */}
                <OpportunityTable
                    opportunities={opportunities}
                    loading={loadingList}
                    onSelect={handleSelect}
                    pagination={pagination}
                    onPageChange={setPage}
                />
            </main>

            {/* Detail modal */}
            <OpportunityDetail opportunity={selected} onClose={() => setSelected(null)} />
        </div>
    )
}
