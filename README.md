# Avenue

Highly-extensible, open-source generic components that enables you to
Create dynamic end-to-end [Vapor](https://vapor.codes) REST APIs with little or no coding based on your models.

### Getting Started

If this is your first time using [Vapor](https://vapor.codes/), head to the documentation install section to install Swift and Vapor.
Double check the installation was successful by opening Terminal and running:

```
vapor --help
```

### Adding routes

Create REST APIs with no coding. Access data from PostgreSQL database.
Incorporate model relationships and access controls for complex APIs.

#### CRUD

Adding CRUD routes for your model is easy as:

```
_ = MainController<Model>(router: router)
```

We are using here generic `MainController` which requires your model as generic constrain and router to which routes should be populated.

#### Child

Adding Parent-Child relation ship routes works in similar way. We specify parent model type which is `Vendor` in following example and child which is `Product`. Moreover, next to the router instance we need to pass keypath for child-parent link so our generic controller can create corresponding queries. 

```
_ = ChildController<Vendor, Product>(router: router, keypath: \Product.vendorID)
```

#### Sibling

Final controller is `SiblingController`. Responsible for population of routes in regards of sibling relationship. 
Here we will need sibling models such as `List` and `Product` in following example and Pivot table model which is `ListProduct`. In swift keypaths are static that's why relation controllers require them to be passed alone with router. Thanks to that we can query objects on both sides of relation. 

```
_ = SiblingController<List, Product, ListProduct>(router: router, keypathLeft: ListProduct.leftIDKey, keypathRight: ListProduct.rightIDKey)
```

#### Example

Best example of *How To* is present in [tests](Tests/AvenueTests) 


### Routes query & filters

A query is a read operation on models that returns a set of data or results. 
You can query models using filters, as outlined. 
Filters specify criteria for the returned data set.

#### order

Order allows us to sort by given key. By default sort order is ascending.

```
www.abc.com/my/path?order[key]=timespamp
```

To sort collection in descending way we need to specify another optional flag

```
www.abc.com/my/path?order[key]=timespamp&order[descending]=true
```

where `index` represents starting offset of a query and `length` limits the size of the maximum results number equals to it.

#### skip (offset)

In other way limiting the size of response, offsetting or using pagination. 
To do that we simply operate on two query parameter

```
www.abc.com/my/path?offset[length]=12&offset[index]=18
```

where `index` represents starting offset of a query and `length` limits the size of the maximum results number equals to it.

#### where

To filter and query by fields we will need more complicated example.
Which accepts multiple filter instances indexed.

Filter query requires `operator`, `value` and `key` to be present. Whole group should be wrapped in `where` parent such as `where[1]`. 
Index inside where helps to decode correct group values to same filter model instance inside from which query is created.  

```
www.abc.com/my/path?where[1][key]=title&where[1][operator]==&where[1][value]=Test%20Name"
```

## Display Routes
To display routes run in your terminal
```
 vapor build
 vapor run routes
```
