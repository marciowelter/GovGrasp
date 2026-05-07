import { useState } from 'react'
import { triggerWorker } from '../api/client'

const DOT = {
    running: 'bg-yellow-400 animate-pulse',
    completed: 'bg-green-500',
    failed: 'bg-red-500',
}

function fmtDate(dt) {
    if (!dt) return '—'
    return new Date(dt).toLocaleString('en-GB', { dateStyle: 'short', timeStyle: 'short' })
}

export default function WorkerStatus({ workerStatus, onTriggered }) {
    const [triggering, setTriggering] = useState(false)
    const [error, setError] = useState(null)

    const lastRun = workerStatus?.last_run ?? workerStatus?.worker_status?.last_run
    const isRunning = workerStatus?.worker_status?.is_running

    async function handleTrigger() {
        setTriggering(true)
        setError(null)
        try {
            await triggerWorker()
            onTriggered?.()
        } catch (err) {
            setError(err?.response?.data?.message ?? 'Worker unreachable. Is the container running?')
        } finally {
            setTriggering(false)
        }
    }

    return (
        <div className="flex flex-col sm:flex-row sm:items-center gap-3">
            {/* Status pill */}
            {lastRun && (
                <div className="flex items-center gap-2 text-sm text-gray-600 bg-white border border-gray-200 rounded-full px-3 py-1.5 shadow-sm">
                    <span className={`w-2.5 h-2.5 rounded-full shrink-0 ${DOT[lastRun.status] ?? 'bg-gray-400'}`} />
                    <span>
                        Last run: <strong className="text-gray-900">{lastRun.status}</strong>
                        {' — '}{lastRun.opportunities_qualified}/{lastRun.opportunities_fetched} qualified
                        {' — '}{fmtDate(lastRun.completed_at ?? lastRun.started_at)}
                    </span>
                </div>
            )}

            {/* Trigger button */}
            <button
                onClick={handleTrigger}
                disabled={triggering || isRunning}
                className="flex items-center gap-2 px-4 py-2 bg-blue-600 hover:bg-blue-700 disabled:opacity-60 text-white text-sm font-semibold rounded-lg shadow-sm transition"
            >
                {triggering || isRunning ? (
                    <>
                        <svg className="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
                            <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
                            <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8H4z" />
                        </svg>
                        Running…
                    </>
                ) : (
                    <>▶ Run Pipeline</>
                )}
            </button>

            {error && <p className="text-xs text-red-600">{error}</p>}
        </div>
    )
}
