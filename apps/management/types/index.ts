export interface ManagementUser {
  id: string;
  email: string;
  password_changed_at: string | null;
}

export interface Organization {
  id: string;
  name: string;
  created_at: string;
}
