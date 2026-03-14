/// Maps Supabase auth errors to user-friendly Chinese messages.
///
/// Used by login_screen, register_screen, and setup_profile_screen
/// to avoid exposing raw exception details to users.
String formatAuthError(Object error) {
  final msg = error.toString().toLowerCase();

  // Invalid credentials (wrong password or non-existent account)
  if (msg.contains('invalid login credentials') ||
      msg.contains('invalid_credentials')) {
    return '手机号或密码错误';
  }

  // User already exists
  if (msg.contains('user_already_exists') ||
      msg.contains('already registered')) {
    return '该手机号已注册，请直接登录';
  }

  // Invalid email format (triggered when phone format is wrong)
  if (msg.contains('invalid email') || msg.contains('invalid_email')) {
    return '手机号格式不正确';
  }

  // Password too short or weak
  if (msg.contains('password') &&
      (msg.contains('short') || msg.contains('weak'))) {
    return '密码至少需要6位';
  }

  // Rate limiting
  if (msg.contains('rate limit') ||
      msg.contains('too many requests') ||
      msg.contains('429')) {
    return '操作过于频繁，请稍后再试';
  }

  // Network errors
  if (msg.contains('socket') ||
      msg.contains('network') ||
      msg.contains('connection') ||
      msg.contains('timeout') ||
      msg.contains('failed host lookup')) {
    return '网络连接失败，请检查网络后重试';
  }

  // Server errors
  if (msg.contains('500') ||
      msg.contains('502') ||
      msg.contains('503') ||
      msg.contains('server')) {
    return '服务器繁忙，请稍后再试';
  }

  // Fallback: concise message without technical details
  return '操作失败，请稍后重试';
}
