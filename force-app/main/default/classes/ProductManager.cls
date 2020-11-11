/****************************************************************************************
Name            : ProductManager
Revision Log    : 8/12/2020 Bryan
                :
                :
Use             : Used to work with the CPQ API
*****************************************************************************************/
public with sharing class ProductManager {

    public QuoteModel addProduct(QuoteModel quote, ProductModel[] products, Integer groupKey) {
        AddProductContext ctx = new AddProductContext(quote, products, groupKey);
        String quoteJSON = SBQQ.ServiceRouter.load('SBQQ.QuoteAPI.QuoteProductAdder', null, JSON.serialize(ctx));
        return (QuoteModel) JSON.deserialize(quoteJSON, QuoteModel.class);
    }

    public ProductModel readProduct(Id productId, Id pricebookId, String currencyCode) {
        ProductReaderContext ctx = new ProductReaderContext(pricebookId, currencyCode);
        String productJSON = SBQQ.ServiceRouter.load('SBQQ.ProductAPI.ProductLoader', productId, JSON.serialize(ctx));
        return (ProductModel) JSON.deserialize(productJSON, ProductModel.class);
    }

    public List<String> validate(QuoteModel quote) {
        String res = SBQQ.ServiceRouter.load('SBQQ.QuoteAPI.QuoteValidator', null, JSON.serialize(quote));
        return (List<String>) JSON.deserialize(res, List<String>.class);
    }

    public QuoteModel load(String contractId) {
        String quoteJSON = SBQQ.ServiceRouter.load('SBQQ.ContractManipulationAPI.ContractAmender', contractId, null);
        return (QuoteModel) JSON.deserialize(quoteJSON, QuoteModel.class);
    }

    public class AddProductContext {
        public QuoteModel quote;
        public ProductModel[] products;
        public Integer groupKey;
        public final Boolean ignoreCalculate = true; //Must be hardcoded to true

        public AddProductContext(QuoteModel quote, ProductModel[] products, Integer groupKey) {
            this.quote = quote;
            this.products = products;
            this.groupKey = groupKey;
        }
    }

    public class ProductReaderContext {
        public Id pricebookId;
        public String currencyCode;
        public ProductReaderContext(Id pricebookId, String currencyCode) {
            this.pricebookId = pricebookId;
            this.currencyCode = currencyCode;
        }
    }
}