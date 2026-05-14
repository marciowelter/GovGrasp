import { render, screen } from '@testing-library/react';
import StatsBar from '../components/StatsBar';

describe('StatsBar', () => {
  it('renders all stat cards with correct labels', () => {
    render(<StatsBar stats={{ total: 10, qualified: 5, rejected: 2, today: 3 }} loading={false} />);
    expect(screen.getByText('Total')).toBeInTheDocument();
    expect(screen.getByText('Qualified')).toBeInTheDocument();
    expect(screen.getByText('Rejected')).toBeInTheDocument();
    expect(screen.getByText('Today')).toBeInTheDocument();
    expect(screen.getByText('10')).toBeInTheDocument();
    expect(screen.getByText('5')).toBeInTheDocument();
    expect(screen.getByText('2')).toBeInTheDocument();
    expect(screen.getByText('3')).toBeInTheDocument();
  });

  it('shows dash when stats are missing', () => {
    render(<StatsBar stats={{}} loading={false} />);
    expect(screen.getAllByText('—').length).toBe(4);
  });

  it('applies loading animation', () => {
    render(<StatsBar stats={{}} loading={true} />);
    expect(document.querySelectorAll('.animate-pulse').length).toBe(4);
  });
});
