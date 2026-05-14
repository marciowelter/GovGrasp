import { render, screen, fireEvent } from '@testing-library/react';
import OpportunityDetail from '../components/OpportunityDetail';

describe('OpportunityDetail', () => {
  const opportunity = {
    title: 'Test Opportunity',
    buyer_name: 'Test Buyer',
    status: 'qualified',
    value: 10000,
    currency: 'GBP',
    published_at: '2024-05-01',
    deadline: '2024-06-01',
    description: 'A test opportunity',
    location: 'London',
    link: 'https://example.com',
  };

  it('renders opportunity details', () => {
    render(<OpportunityDetail opportunity={opportunity} onClose={() => {}} />);
    expect(screen.getByText('Test Opportunity')).toBeInTheDocument();
    expect(screen.getByText('Test Buyer')).toBeInTheDocument();
    expect(screen.getByText('A test opportunity')).toBeInTheDocument();
    expect(screen.getByText('London')).toBeInTheDocument();
  });

  it('calls onClose when close button is clicked', () => {
    const onClose = jest.fn();
    render(<OpportunityDetail opportunity={opportunity} onClose={onClose} />);
    fireEvent.click(screen.getByLabelText('Close'));
    expect(onClose).toHaveBeenCalled();
  });

  it('renders nothing if opportunity is null', () => {
    const { container } = render(<OpportunityDetail opportunity={null} />);
    expect(container.firstChild).toBeNull();
  });
});
