import { render } from '@testing-library/react';
import { useRouter } from 'next/navigation';
import { AuthGuard } from './auth-guard';

const mockReplace = jest.fn();

jest.mock('next/navigation', () => ({
  useRouter: () => ({ replace: mockReplace }),
}));

jest.mock('@/hooks/use-auth', () => ({
  useAuth: () => ({ user: null, loading: false }),
}));

jest.mock('@/lib/supabase/client', () => ({
  createClient: () => ({}),
}));

describe('AuthGuard', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('redirects to /login when user is null', () => {
    render(
      <AuthGuard>
        <div>Protected content</div>
      </AuthGuard>
    );

    expect(mockReplace).toHaveBeenCalledWith('/login');
  });

  it('does not render children when user is null', () => {
    const { queryByText } = render(
      <AuthGuard>
        <div>Protected content</div>
      </AuthGuard>
    );

    expect(queryByText('Protected content')).not.toBeInTheDocument();
  });
});
