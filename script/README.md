** STEPS **

DEPLOY STRATEGY:
1. Use the factory
2. acceptManagement()
3. setMaxProfitUnlockTime() to 86400

DEPLOY ALLOCATOR VAULT
1. Registry.newEndorsedVault() (If no RoleManager - RoleManagerFactory.newProject())
2. vault.set_role(address, 16383) // 16383 == ADD_STRATEGY_MANAGER/DEPOSIT_LIMIT_MANAGER/MAX_DEBT_MANAGER/DEBT_MANAGER
3. vault.set_deposit_limit(uint256 deposit_limit)
4. vault.add_strategy(address new_strategy)
5. vault.update_max_debt_for_strategy(address strategy,uint256 new_max_debt)

DEPLOY APR ORACLE
1. call `setOracle()` from the strategy's management on the central apr oracle

** YEARN **

DEPLOYED ADDRESSES (all EVM - if not deployed, use https://github.com/wavey0x/yearn-v3-deployer):
- RoleManagerFactory - 0xca12459a931643BF28388c67639b3F352fe9e5Ce
- Address Provider - 0x775F09d6f3c8D2182DFA8bce8628acf51105653c
- Registry - 0xd40ecF29e001c76Dcc4cC0D9cd50520CE845B038
- Central AprOracle - 0x1981AD9F44F2EA9aDd2dC4AD7D075c102C70aF92

** SONIC **

DEPLOYED ADDRESSES:
- SiloV2Lender Factory - 0x61810a90128Ee5c5F5a3730f0449Da9E9480f888
- Swapper (toSonic==false) - 0x71ccF86Cf63A5d55B12AA7E7079C22f39112Dd7D
--
- SMS - 0x35442eC4C1A0C4E864c2Bc45bfc5d17fCEE8ac4C
- Chad - 0x4cdB5768b226d279dBcbF593eA94f5098e3537b4
- RoleManager - 0xC80519046D25Cc44e1D40c930adf7C6E9817aE90
--
- Silo Lender S/USDC (8) - 0x3FfA0C3fba4Adfe2b6e4D7E2f8E6e6324bE5305B
- Silo Lender S/USDC (20) - 0xf1dF9a0390Fd65984F311f17230B9F6B85497C6e
--
- APR Oracle - 0xDd737dADA46F3A111074dCE29B9430a7EA000092
--
- USDC-2 yVault - 0xb9228370e2fa4908FC2Bf559a50bB77ba66fDD66