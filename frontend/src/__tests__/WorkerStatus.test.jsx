import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import WorkerStatus from '../components/WorkerStatus';

jest.mock('../api/client', () => ({
  triggerWorker: jest.fn(() => Promise.resolve()),
}));

const { triggerWorker } = require('../api/client');

describe('WorkerStatus', () => {
  const workerStatus = {
    last_run: {
      status: 'completed',
      opportunities_qualified: 2,
      opportunities_fetched: 5,
      completed_at: '2024-05-14T10:00:00Z',
      started_at: '2024-05-14T09:00:00Z',
    },
    worker_status: {
      is_running: false,
      last_run: {
        status: 'completed',
        opportunities_qualified: 2,
        opportunities_fetched: 5,
        completed_at: '2024-05-14T10:00:00Z',
        started_at: '2024-05-14T09:00:00Z',
      },
    },
  };

  it('renders last run status', () => {
    render(<WorkerStatus workerStatus={workerStatus} />);
    expect(screen.getByText(/Last run:/)).toBeInTheDocument();
    expect(screen.getByText(/2\/5 qualified/)).toBeInTheDocument();
  });

  it('triggers worker on button click', async () => {
    const onTriggered = jest.fn();
    render(<WorkerStatus workerStatus={workerStatus} onTriggered={onTriggered} />);
    fireEvent.click(screen.getByRole('button'));
    await waitFor(() => expect(triggerWorker).toHaveBeenCalled());
    await waitFor(() => expect(onTriggered).toHaveBeenCalled());
  });
});
