public with sharing class LoadRuleRunner {
    public ProductModel load(
        Id productId,
        QuoteModel quote,
        Integer lineItemKey,
        List<String> dynamicOptionSkus,
        ConfigurationModel configuration,
        ProductModel parentProduct) {
        
        LoadRuleRunnerContext ctx = new LoadRuleRunnerContext(
            quote,
            lineItemKey,
            dynamicOptionSkus,
            configuration,
            parentProduct);
        String productJSON = SBQQ.ServiceRouter.load('SBQQ.ConfigAPI.LoadRuleExecutor', productId, JSON.serialize(ctx));
        return (ProductModel) JSON.deserialize(productJSON, ProductModel.class);
    }

    private class LoadRuleRunnerContext {
        private QuoteModel quote;
        private ProductModel parentProduct;
        private Integer lineItemKey;
        private List<String> dynamicOptionSkus;
        public ConfigurationModel configuration;

        public LoadRuleRunnerContext(
            QuoteModel quote,
            Integer lineItemKey,
            List<String> dynamicOptionSkus,
            ConfigurationModel configuration,
            ProductModel parentProduct) {
            
            this.quote = quote;
            this.parentProduct = parentProduct;
            this.lineItemKey = lineItemKey;
            this.dynamicOptionSkus = dynamicOptionSkus;
            this.configuration = configuration;
        }
    }
}