**Salesforce CPQ - Cancel and Replace**

License

THIS APPLICATION IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, CONSEQUENTIAL OR SIMILAR DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS APPLICATION, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
SUBJECT TO THE FOREGOING, THIS APPLICATION MAY BE FREELY REPRODUCED, DISTRIBUTED, TRANSMITTED, USED, MODIFIED, BUILT UPON, OR OTHERWISE EXPLOITED BY OR ON BEHALF OF SALESFORCE.COM OR ITS AFFILIATES, ANY CUSTOMER OR PARTNER OF SALESFORCE.COM OR ITS AFFILIATES, OR ANY DEVELOPER OF APPLICATIONS THAT INTERFACE WITH THE SALESFORCE.COM APPLICATION, FOR ANY PURPOSE, COMMERCIAL OR NON-COMMERCIAL, RELATED TO USE OF THE SALESFORCE.COM APPLICATION, AND IN ANY WAY, INCLUDING BY METHODS THAT HAVE NOT YET BEEN INVENTED OR CONCEIVED.

Documentation Link: https://salesforce.quip.com/KXBRArvmUQcG

*OVERVIEW*

One of the most common scenarios not supported directly with amendments is the ability to combine multiple contracts onto into a single contract and EXTEND that contract beyond the original term. From a functionality perspective, this is known as *Cancel & Replace*, as the original contracts are cancelled with negative orders and a new quote is created for the customer going forward.

The Cancel & Replace framework is designed to provide a *pattern* for advanced contract manipulation via customization. While you may choose to install the managed package from the app exchange, the full codebase will be released as open source software available on Github.


## Code Style and Formatting

- Install Prettier VSCode extension
- Install VSCode ESLint extension
- Install Apex PMD ESLint extension
- In the root directory, run npm install to install necessary packages.
- Add these attributes to your vscode workspace settings (.vscode/settings.json)

```javascript
{
    "editor.codeActionsOnSave": {
        "source.fixAll": true
    },
    "eslint.format.enable": true,
    "eslint.lintTask.enable": true,
    "apexPMD.rulesets": ["pmd/pmd_rules.xml"],
}
```
---
## Developer setup (scripted)

1. merge/rebase from `managed-integration`
2. from project root run `./setup.sh orgname [duration]`
    - this command automates many of the manual steps detailed below.
    - the setup.sh script performs the following:

    ```
    // create project       sfdx force:org:create -s -f config/project-scratch-def.json -a $alias -d $duration;
    // set cli alias        sfdx force:config:set defaultusername=$alias
    // install cpq          sfdx force:package:install -r -p $packageversion -w 30 -u $alias -s AllUsers
    // push local source    sfdx force:source:push -f
    // create test user     sfdx force:user:create --setalias cpq-user --definitionfile config/cpquser.json
    // cli user perms       sfdx force:user:permset:assign --permsetname $permset
    ```

3. Post Install, you must Authorize new calculation service.  
    - this step requires logging and performing the following step:
**Setup > Installed Packages > Salesforce CPQ Configure > Pricing and Calculation > Click Authorize new calculation service**
    - if you receive an error at this step, the CPQ remote site settings did not get activated during package install.  Go to **Setup > Remote Site Settings** and activate all of them.
4. Data seeding automation
    Run these scripts from your command line one at a time letting them finish before you run the next.
    - you must go to *Apex Jobs* in *Setup* to monitor the progress of each of these jobs and only start the next job when the prior one has finished.    
        ```
        sfdx force:apex:execute -f force-app/main/unpackaged/anon-apex/loadQuotes.apex 
        sfdx force:apex:execute -f force-app/main/unpackaged/anon-apex/placeOrders.apex
        sfdx force:apex:execute -f force-app/main/unpackaged/anon-apex/activateOrders.apex
        sfdx force:apex:execute -f force-app/main/unpackaged/anon-apex/contractQuotes.apex
        sfdx force:apex:execute -f force-app/main/unpackaged/anon-apex/activateContracts.apex
        ```
---

## Developer setup (manual)

1. merge/rebase from **managed-integration** to your dev branch
2. pull your dev branch (remote -> local)
3. create your DE Scratch Org (SO)
4. install CPQ Package (see below)
6. sfdx force:source:push your local workspace to scratch org (project contains project permset **Salesforce_CPQ_Cancel_and_Replace** that admin user needs)
7. Assign permset to cli Admin User
8. Post Install Config Setup

### Create a Scratch Org

- `sfdx force:org:create -a orgalias-name -f config/project-scratch-def.json -s`

### Installing CPQ Package in your Scratch Org (SO)

SBQQ 226.3 - Summer 20

- `sfdx force:package:install -p "04t4N000000YTOgQAO"`
- Post Install, you must Authorize new calculation service.  This step requires logging and performing the following step: **Setup > Installed Packages > Salesforce CPQ Configure > Pricing and Calculation > Click Authorize new calculation service****

### Push local repo to SO

- `sfdx force:source:push -f`

### User Setup

Assign the following permission sets to your default org User.

- `sfdx force:user:permset:assign --permsetname Salesforce_CPQ_Cancel_and_Replace`
- `sfdx force:user:permset:assign --permsetname SBQQ__SteelBrickCPQAdmin`
- `sfdx force:user:permset:assign --permsetname SBQQ__SteelBrickCPQUser`

Create demo/test User with this project and CPQ permsets pre-configured.

- `sfdx force:user:create --setalias cpq-user --definitionfile config/cpquser.json`

### Post Install Config Setup

- assign your Scrath Org User to the **CPQ Dev** Profile
- assing your Scrath Org User to the **Salesforce_CPQ_Cancel_and_Replace,**
     **SBQQ__SteelBrickCPQAdmin,** **SBQQ__SteelBrickCPQUser** permission sets
  
### Populating Test Data

1. Create 1 Account.  SBQQ__RenewalModel__c = 'Contract Based'
2. Create 1 Product.  IsActive=TRUE, SBQQ__QuantityEditable__c=TRUE, SBQQ__SubscriptionPricing__c='Fixed Price', SBQQ__SubscriptionTerm__c='1'
3. Add the Product you just created to the Standard Pricebook and give it a Standard Price.
4. Create an Opportunity.
5. Set Opportunity Pricebook to Standard
6. Add Product to Opportunity as an Opportunity Line Item
7. Create SBQQ__Quote__c record with lookups set to Account, Opportunity, Pricebook Primary=TRUE, Start Date != null, Subscription Terms = 36
8. Create Order by setting SBQQ__Quote__c.SBQQ__Ordered__c=TRUE.
9. Create Contract by setting Opportunity.SBQQ__Contracted=TRUE.
***if you have done this correctly so far, you should see a Subscription child record looking up to your Contract***

10. Click "Activate" button on Contract record.
11. from Quote record, set the Master Contract lookup to the Contract you just created.

***This is the minimum starting data setup required to apply the Amend and Replace business rules****
