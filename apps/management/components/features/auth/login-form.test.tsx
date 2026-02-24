import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { LoginForm } from './login-form';

const mockManagementLogin = jest.fn();

jest.mock('@/lib/api/management', () => ({
  managementLogin: (...args: unknown[]) => mockManagementLogin(...args),
  ManagementApiException: class ManagementApiException extends Error {
    status: number;
    constructor(message: string, status: number) {
      super(message);
      this.name = 'ManagementApiException';
      this.status = status;
    }
  },
}));

jest.mock('@/lib/supabase/client', () => ({
  createClient: () => ({
    auth: {
      setSession: jest.fn().mockResolvedValue({ error: null }),
    },
  }),
}));

jest.mock('sonner', () => ({
  toast: { error: jest.fn(), success: jest.fn() },
}));

describe('LoginForm', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('renders email and password inputs and submit button', () => {
    render(<LoginForm />);
    expect(screen.getByLabelText(/correo electronico/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/contrasena/i)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /ingresar/i })).toBeInTheDocument();
  });

  it('does not call managementLogin when submitting with empty email', async () => {
    const user = userEvent.setup();
    render(<LoginForm />);
    await user.click(screen.getByRole('button', { name: /ingresar/i }));
    expect(mockManagementLogin).not.toHaveBeenCalled();
  });

  it('calls managementLogin with email and password on submit', async () => {
    mockManagementLogin.mockResolvedValue({
      access_token: 'tok',
      refresh_token: 'ref',
      expires_in: 3600,
    });
    const user = userEvent.setup();
    render(<LoginForm />);
    await user.type(screen.getByLabelText(/correo electronico/i), 'admin@test.com');
    await user.type(screen.getByLabelText(/contrasena/i), 'ValidPass1');
    await user.click(screen.getByRole('button', { name: /ingresar/i }));
    await expect(mockManagementLogin).toHaveBeenCalledWith('admin@test.com', 'ValidPass1');
  });
});
