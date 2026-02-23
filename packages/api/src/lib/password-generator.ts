const CHARSET_UPPER = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
const CHARSET_LOWER = 'abcdefghjkmnpqrstuvwxyz';
const CHARSET_DIGIT = '23456789';
const CHARSET_ALL = CHARSET_UPPER + CHARSET_LOWER + CHARSET_DIGIT;
const LENGTH = 12;

function pickRandom(charset: string): string {
  const buf = new Uint8Array(1);
  crypto.getRandomValues(buf);
  const idx = buf[0]! % charset.length;
  return charset[idx] ?? charset[0]!;
}

export function generateTempPassword(): string {
  const arr: string[] = [];
  for (let i = 0; i < LENGTH; i++) {
    arr.push(pickRandom(CHARSET_ALL));
  }
  if (!/[A-Z]/.test(arr.join(''))) {
    arr[0] = pickRandom(CHARSET_UPPER);
  }
  if (!/[2-9]/.test(arr.join(''))) {
    arr[1] = pickRandom(CHARSET_DIGIT);
  }
  return arr.join('');
}
