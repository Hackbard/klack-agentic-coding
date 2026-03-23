module.exports = {
  extends: ['@commitlint/config-conventional'],
  rules: {
    // Add new scopes here as the project grows
    'scope-enum': [2, 'always', [
      'cli', 'pipeline', 'hauptturm', 'protocol',
      'ci', 'docs', 'packaging', 'release',
      'skills', 'tmux', 'epic', 'config'
    ]],
    'scope-empty': [2, 'never']
  }
};
