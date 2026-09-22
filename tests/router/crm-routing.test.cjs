/* Run: node --experimental-vm-modules --test tests/router/crm-routing.test.cjs
 * Executes production routes, guards, account loading and tab scripts.
 * Only HTTP, unrelated app routes, lazy rendering and lifecycle mounting are stubbed.
 */
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');
const vue = require('vue');
const vueRouter = require('vue-router');
const { parse } = require('@vue/compiler-sfc');

const root = path.resolve(__dirname, '../..');
const dashboard = path.join(root, 'app/javascript/dashboard');
const crm = path.join(dashboard, 'routes/dashboard/crm');

async function setup() {
  const records = [];
  const requests = [];
  const features = new Map([[1, true], [2, false]]);
  let rejectHttp = false;
  let activeRouter;
  let activeRoute;
  let crmRoutes;
  let accountModule;
  const store = {
    getters: {
      isLoggedIn: true,
      getCurrentAccount: {},
      getCurrentUser: {
        id: 1, account_id: 1,
        accounts: [{ id: 1, role: 'administrator', permissions: ['administrator'], crm_enabled: false, status: 'active' }],
      },
    },
    commit(type, data) {
      if (type === 'ADD_ACCOUNT') {
        const index = records.findIndex(record => record.id === data.id);
        if (index < 0) records.push(data);
        else records[index] = data;
      }
    },
    async dispatch(type, payload) {
      if (type === 'accounts/get') return accountModule.actions.get({ commit: store.commit }, payload);
      if (type === 'setUser') return undefined;
      throw new Error('Unexpected dispatch: ' + type);
    },
  };
  const context = vm.createContext({
    console, URLSearchParams,
    window: { location: { pathname: '/app/accounts/99/dashboard', assign() {} } },
    axios: { async get(url) {
      requests.push(url);
      if (rejectHttp) throw new Error('HTTP unavailable');
      const id = Number(url.match(/accounts\/(\d+)/)?.[1]);
      return { data: { id, features: { jrc_crm: features.get(id) || false } } };
    } },
  });
  const modules = new Map();
  function synthetic(key, exports) {
    if (!modules.has(key)) {
      modules.set(key, new vm.SyntheticModule(Object.keys(exports), function initialize() {
        Object.entries(exports).forEach(([name, value]) => this.setExport(name, value));
      }, { context, identifier: key }));
    }
    return modules.get(key);
  }
  async function load(filename, tabScript = false) {
    if (modules.has(filename)) return modules.get(filename);
    let source = fs.readFileSync(filename, 'utf8');
    if (tabScript) source = parse(source).descriptor.scriptSetup.content + '\nexport { tabs, tab, goTab };';
    const module = new vm.SourceTextModule(source, {
      context, identifier: filename,
      importModuleDynamically: async specifier => {
        const dependency = await link(specifier, module);
        if (dependency.status === 'unlinked') await dependency.link(link);
        if (dependency.status === 'linked') await dependency.evaluate();
        return dependency;
      },
    });
    modules.set(filename, module);
    await module.link(link);
    return module;
  }
  async function link(specifier, parent) {
    if (specifier === 'vue-router') return synthetic(specifier, {
      ...vueRouter, createWebHistory: vueRouter.createMemoryHistory,
      useRoute: () => activeRoute, useRouter: () => activeRouter,
    });
    if (specifier === 'vue') return synthetic(specifier, { ...vue, onMounted() {} });
    if (specifier === 'dashboard/store') return synthetic(specifier, { default: store });
    if (specifier.endsWith('/dashboard.routes')) return synthetic(specifier, { default: {
      routes: [...crmRoutes.routes,
        { path: '/app/accounts/:accountId/dashboard', name: 'home', component: {}, meta: { permissions: ['administrator', 'agent', 'conversation_manage', 'conversation_unassigned_manage', 'conversation_participating_manage'] } },
        { path: '/app/accounts/:accountId/suspended', name: 'account_suspended', component: {}, meta: { permissions: ['administrator', 'agent', 'custom_role'] } },
      ],
    } });
    if (specifier === 'v3/helpers/RouteHelper') return synthetic(specifier, {
      isOnOnboardingView: route => String(route.name || '').includes('onboarding_'),
    });
    if (specifier.endsWith('/AnalyticsHelper')) return synthetic(specifier, { default: { page() {} } });
    if (specifier.endsWith('mutation-types')) return synthetic(specifier, { default: {
      ADD_ACCOUNT: 'ADD_ACCOUNT', SET_ACCOUNT_UI_FLAG: 'SET_ACCOUNT_UI_FLAG',
    } });
    if (specifier === 'shared/helpers/vuex/mutationHelpers') return synthetic(specifier, {
      setSingleRecord() {}, update() {}, updateAttributes() {},
    });
    if (specifier === 'date-fns') return synthetic(specifier, { differenceInDays() {} });
    if (specifier.endsWith('/languages')) return synthetic(specifier, { getLanguageDirection() {} });
    if (specifier.endsWith('/utils/api')) return synthetic(specifier, { throwErrorMessage(error) { throw error; } });
    if (specifier === 'dashboard/composables') return synthetic(specifier, { useAlert() {} });
    if (specifier === 'dashboard/api/crm/commercialCycle') return synthetic(specifier, {
      commissionsAPI: {}, commissionProgramsAPI: {}, backofficeAPI: {}, invoicesAPI: {}, paymentsAPI: {}, salesOrdersAPI: {},
    });
    if (specifier.endsWith('.vue')) return synthetic(specifier, { default: {} });
    if (['../../api/onboarding', '../../api/enterprise/account', 'dashboard/api/agents',
      'dashboard/api/teams', 'dashboard/api/crm/products'].includes(specifier)) {
      return synthetic(specifier, { default: {} });
    }
    if (!specifier.startsWith('.') && !specifier.startsWith('dashboard/')) {
      return synthetic(specifier, require(specifier));
    }
    let filename = specifier.startsWith('dashboard/')
      ? path.join(dashboard, specifier.slice(10))
      : path.resolve(path.dirname(parent.identifier), specifier);
    if (!path.extname(filename) || filename.endsWith('.routes')) filename += '.js';
    return load(filename);
  }
  accountModule = await load(path.join(dashboard, 'store/modules/accounts.js'));
  await accountModule.evaluate();
  accountModule = accountModule.namespace;
  store.getters['accounts/isFeatureEnabledonAccount'] = accountModule.getters.isFeatureEnabledonAccount({ records });
  const routeModule = await load(path.join(crm, 'crm.routes.js'));
  await routeModule.evaluate();
  crmRoutes = routeModule.namespace.default;
  const index = await load(path.join(dashboard, 'routes/index.js'));
  await index.evaluate();
  index.namespace.initalizeRouter();
  activeRouter = index.namespace.router;
  return {
    router: activeRouter, store, requests, features, records,
    failHttp() { rejectHttp = true; },
    accounts: accountModule,
    async view(folder, filename, section) {
      activeRoute = vue.reactive({ params: { accountId: '1', section } });
      const module = await load(path.join(crm, 'views', folder, filename), true);
      await module.evaluate();
      return { ...module.namespace, route: activeRoute };
    },
    async access(section, accountId = 1) {
      const module = await load(path.join(crm, 'access.js'));
      await module.evaluate();
      return module.namespace.ensureCrmEnabled({ params: { accountId, section } });
    },
  };
}

const primary = ['dashboard', 'indicators', 'leads', 'deals', 'funnel', 'wallet', 'activities',
  'calendar', 'products', 'proposals', 'orders', 'contracts', 'goals'];
const commissions = ['current', 'plans', 'new', 'closing', 'detail', 'approvals', 'adjustments', 'payments', 'mine', 'history'];
const backoffice = ['overview', 'requests', 'process', 'docs', 'implement', 'provision', 'finance', 'issues', 'approvals', 'changes', 'sla', 'reports'];
const paths = [...primary, 'commissions', ...commissions.map(section => 'commissions/' + section),
  'backoffice', ...backoffice.map(section => 'backoffice/' + section)];

for (const route of paths) {
  test('direct entry and fresh router: /crm/' + route, async () => {
    const app = await setup();
    const url = '/app/accounts/1/crm/' + route;
    await app.router.push(url);
    assert.equal(app.router.currentRoute.value.path, url);
    assert.ok(app.router.currentRoute.value.name.startsWith('crm_'));
    assert.equal(app.requests.at(-1), '/api/v1/accounts/1');
  });
}

for (const [folder, file, sections] of [
  ['commissions', 'CommissionsView.vue', commissions],
  ['backoffice', 'BackofficeView.vue', backoffice],
]) {
  test(folder + ': actual tab handlers and watchers preserve section', async () => {
    const app = await setup();
    const scope = vue.effectScope();
    const view = await scope.run(() => app.view(folder, file, sections[1]));
    assert.deepEqual(Array.from(view.tabs, row => row[0]), sections);
    assert.equal(view.tab.value, sections[1]);
    for (const section of sections) {
      view.goTab(section);
      await new Promise(resolve => setImmediate(resolve));
      assert.equal(app.router.currentRoute.value.params.section, section);
      view.route.params.section = section;
      await vue.nextTick();
      assert.equal(view.tab.value, section);
    }
    view.route.params.section = undefined;
    await vue.nextTick();
    assert.equal(view.tab.value, sections[0]);
    scope.stop();
  });
}

test('agent with CRM permission allowed; without it denied', async () => {
  const app = await setup();
  const account = app.store.getters.getCurrentUser.accounts[0];
  account.role = 'agent';
  account.permissions = ['agent', 'jrc_crm'];
  assert.equal(await app.access('plans'), true);
  account.permissions = ['agent'];
  assert.equal(await app.access('plans'), '/app/accounts/1/dashboard');
});

test('feature disabled denies administrator', async () => {
  const app = await setup();
  app.features.set(1, false);
  await app.router.push('/app/accounts/1/crm/commissions/plans');
  assert.equal(app.router.currentRoute.value.path, '/app/accounts/1/dashboard');
});

test('account change on same route rechecks destination feature and permission', async () => {
  const app = await setup();
  app.store.getters.getCurrentUser.accounts.push({ id: 2, role: 'administrator', permissions: ['administrator'], status: 'active' });
  await app.router.push('/app/accounts/1/crm/commissions/plans');
  await app.router.push('/app/accounts/2/crm/commissions/plans');
  assert.equal(app.router.currentRoute.value.path, '/app/accounts/2/dashboard');
  assert.equal(app.requests.at(-1), '/api/v1/accounts/2');
  app.features.set(2, true);
  await app.router.push('/app/accounts/2/crm/backoffice/docs');
  assert.equal(app.router.currentRoute.value.params.section, 'docs');
});

test('membership of another account does not authorize target', async () => {
  const app = await setup();
  assert.equal(await app.access('plans', 2), '/app/accounts/2/dashboard');
  assert.equal(app.requests.length, 0);
});

test('HTTP failure cannot authorize from previously cached enabled feature', async () => {
  const app = await setup();
  assert.equal(await app.access('plans'), true);
  app.failHttp();
  await assert.rejects(app.access('plans'), /HTTP unavailable/);
});

test('legacy accounts/get still uses current URL when no destination supplied', async () => {
  const app = await setup();
  await app.accounts.actions.get({ commit() {} }, { silent: true });
  assert.equal(app.requests.at(-1), '/api/v1/accounts/99/');
});

test('unknown URL takes global unmatched-route fallback, unlike valid sections', async () => {
  const app = await setup();
  const unmatched = app.router.resolve('/app/accounts/1/crm/commissions/plans/extra');
  assert.equal(unmatched.name, undefined);
  await app.router.push(unmatched.fullPath);
  assert.equal(app.router.currentRoute.value.path, '/app/accounts/1/dashboard');
});
