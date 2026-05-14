import { render, screen, fireEvent } from '@testing-library/react';
import OpportunityTable from '../components/OpportunityTable';

describe('OpportunityTable', () => {
  const opportunities = [
    { id: 1, title: 'Opp 1', status: 'qualified', score: 80, value: 1000, currency: 'GBP', published_at: '2024-05-01', deadline: '2024-06-01' },
    { id: 2, title: 'Opp 2', status: 'rejected', score: 30, value: 2000, currency: 'GBP', published_at: '2024-05-02', deadline: '2024-06-02' },
  ];

  it('renders loading skeletons', () => {
    render(<OpportunityTable loading={true} />);
    expect(document.querySelectorAll('.animate-pulse').length).toBeGreaterThan(0);
  });

  it('renders empty state', () => {
    render(<OpportunityTable opportunities={[]} loading={false} />);
    expect(screen.getByText('No opportunities found.')).toBeInTheDocument();
  });

  it('renders opportunities', () => {
    render(<OpportunityTable opportunities={opportunities} loading={false} />);
    expect(screen.getByText('Opp 1')).toBeInTheDocument();
    expect(screen.getByText('Opp 2')).toBeInTheDocument();
  });

  it('calls onSelect when row clicked', () => {
    const onSelect = jest.fn();
    render(<OpportunityTable opportunities={opportunities} loading={false} onSelect={onSelect} />);
    fireEvent.click(screen.getByText('Opp 1'));
    expect(onSelect).toHaveBeenCalled();
  });
});
