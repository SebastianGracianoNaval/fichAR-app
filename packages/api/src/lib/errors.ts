// plan-refactor-backend: standardized error responses (error, code)

export function errJson(
  status: number,
  error: string,
  code?: string,
): Response {
  const body: { error: string; code?: string } = { error };
  if (code) body.code = code;
  return Response.json(body, { status });
}
