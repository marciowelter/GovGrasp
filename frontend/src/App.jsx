import { useCallback, useEffect, useState } from 'react'
import { deleteAllOpportunities, getOpportunities, getOpportunity, getStats, getWorkerStatus } from './api/client'
import OpportunityDetail from './components/OpportunityDetail'
import OpportunityTable from './components/OpportunityTable'
import StatsBar from './components/StatsBar'
import WorkerStatus from './components/WorkerStatus'

const STATUS_OPTIONS = ['', 'qualified', 'rejected', 'new']

const DEFAULT_COMPANY_PROFILE =
    'NexaTech Solutions Ltd is a global software development and digital transformation ' +
    'company specialising in cloud-native architecture, AI/ML platforms, cybersecurity, and ' +
    'enterprise SaaS. We deliver end-to-end digital services to public and private sector ' +
    'clients across the UK, Europe and North America — from strategy and UX design through ' +
    'agile delivery, DevSecOps, data engineering and managed services. ' +
    'Preferred frameworks: G-Cloud, Digital Outcomes & Specialists (DOS), CCS RM6259.'

function todayISO() {
    return new Date().toISOString().slice(0, 10)
}
function daysAgoISO(n) {
    const d = new Date()
    d.setDate(d.getDate() - n)
    return d.toISOString().slice(0, 10)
}

export default function App() {
    const [opportunities, setOpportunities] = useState([])
    const [pagination, setPagination] = useState(null)
    const [stats, setStats] = useState(null)
    const [workerStatus, setWorkerStatus] = useState(null)
    const [selected, setSelected] = useState(null)
    const [loadingList, setLoadingList] = useState(false)
    const [loadingStats, setLoadingStats] = useState(false)

    // Pipeline filters (sent to the worker on trigger)
    const [startDate, setStartDate] = useState(daysAgoISO(7))
    const [endDate, setEndDate] = useState(todayISO())
    const [companyProfile, setCompanyProfile] = useState(DEFAULT_COMPANY_PROFILE)
    const [deletingAll, setDeletingAll] = useState(false)
    const [deleteError, setDeleteError] = useState(null)

    // Table filters
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

    const liveWorkerStatus = workerStatus?.worker_status
    const isRunning = Boolean(liveWorkerStatus?.is_running || workerStatus?.last_run?.status === 'running')

    async function handleSelect(opp) {
        try {
            const res = await getOpportunity(opp.id)
            setSelected(res.data)
        } catch {
            setSelected(opp)
        }
    }

    async function handleDeleteAll() {
        if (isRunning) {
            setDeleteError('Stop the pipeline before deleting all opportunities.')
            return
        }

        const ok = window.confirm('Delete all imported opportunities and reset the database for reimport?')
        if (!ok) return

        setDeletingAll(true)
        setDeleteError(null)
        try {
            await deleteAllOpportunities()
            setSelected(null)
            setPage(1)
            await Promise.all([fetchStats(), fetchList()])
        } catch (err) {
            setDeleteError(err?.response?.data?.message ?? err?.message ?? 'Failed to delete all opportunities.')
        } finally {
            setDeletingAll(false)
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
                </div>
            </header>

            <main className="max-w-7xl mx-auto px-4 sm:px-6 py-8">
                {/* Stats */}
                <StatsBar stats={stats} loading={loadingStats} />

                {/* Fixed company profile panel */}
                <div className="bg-white border border-gray-200 rounded-xl shadow-sm mb-5 p-4">
                    <label className="text-sm font-semibold text-gray-700 block mb-2">
                        Company profile <span className="text-gray-500 font-medium">(used by the AI analyst to calculate relevance score)</span>
                    </label>
                    <textarea
                        value={companyProfile}
                        onChange={(e) => setCompanyProfile(e.target.value)}
                        rows={5}
                        className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm shadow-sm focus:outline-none focus:ring-2 focus:ring-blue-500 resize-y"
                        placeholder="Describe your company's services, expertise, and target contracts…"
                    />
                    <p className="text-xs text-gray-400 mt-1">
                        This profile is always editable and will be used in the next pipeline run.
                    </p>
                </div>

                {/* Pipeline configuration panel */}
                <div className="bg-white border border-gray-200 rounded-xl shadow-sm mb-5 overflow-hidden">
                    <div className="px-4 py-3 border-b border-gray-100 space-y-3">
                        <h2 className="text-sm font-semibold text-gray-700">🔍 Pipeline Search Settings</h2>

                        <WorkerStatus
                            workerStatus={workerStatus}
                            startDate={startDate}
                            endDate={endDate}
                            companyProfile={companyProfile}
                            onTriggered={() => { fetchStats(); setTimeout(fetchList, 3000) }}
                        />
                    </div>

                    <div className="px-4 py-3 flex flex-col sm:flex-row gap-3">
                        <div className="flex flex-col gap-1">
                            <label className="text-xs font-medium text-gray-500">Start date</label>
                            <input
                                type="date"
                                value={startDate}
                                onChange={(e) => setStartDate(e.target.value)}
                                max={endDate}
                                className="border border-gray-300 rounded-lg px-3 py-2 text-sm shadow-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                            />
                        </div>
                        <div className="flex flex-col gap-1">
                            <label className="text-xs font-medium text-gray-500">End date</label>
                            <input
                                type="date"
                                value={endDate}
                                onChange={(e) => setEndDate(e.target.value)}
                                min={startDate}
                                className="border border-gray-300 rounded-lg px-3 py-2 text-sm shadow-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                            />
                        </div>
                        <div className="flex items-end">
                            <p className="text-xs text-gray-400 pb-2">
                                The pipeline will search all tenders published between these dates and score them using the company profile above.
                            </p>
                        </div>
                    </div>
                </div>

                {/* Table filter bar */}
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

                {/* Footer actions */}
                <footer className="mt-8 border-t border-gray-200 pt-4 flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
                    <p className="text-xs text-gray-500">Need a full reimport? Delete all opportunities and worker runs, then trigger a new pipeline run.</p>
                    <div className="flex items-center gap-3">
                        {deleteError && <p className="text-xs text-red-600">{deleteError}</p>}
                        <button
                            onClick={handleDeleteAll}
                            disabled={deletingAll || isRunning}
                            className="px-4 py-2 text-sm font-semibold rounded-lg border border-red-300 text-red-700 hover:bg-red-50 disabled:opacity-60 transition"
                        >
                            {deletingAll ? 'Deleting...' : isRunning ? 'Stop Pipeline First' : 'Delete All'}
                        </button>
                    </div>
                </footer>
            </main>

            {/* Detail modal */}
            <OpportunityDetail opportunity={selected} onClose={() => setSelected(null)} />
        </div>
    )
}
