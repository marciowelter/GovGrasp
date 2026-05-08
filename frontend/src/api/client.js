import axios from 'axios'

const api = axios.create({
    baseURL: import.meta.env.VITE_API_URL ?? '/api/v1',
    headers: { 'Accept': 'application/json', 'Content-Type': 'application/json' },
})

export const getOpportunities = (params) => api.get('/opportunities', { params })
export const getOpportunity = (id) => api.get(`/opportunities/${id}`)
export const getStats = () => api.get('/opportunities/stats')
export const getWorkerStatus = () => api.get('/worker/status')
export const triggerWorker = (payload = {}) => api.post('/worker/trigger', payload)
export const getWorkerDefaults = () => api.get('/worker/defaults')
