Spark SQL提供了对UDF(User-Defined Function)的支持，用以给开发者更灵活的方式去解决特定的问题。写起来也很简单，只需要一个函数名和一个函数对象便可以完成UDF的注册。如果在运行时也可以注册，应该也是个不错的事情。
``` java
 sqlContext.udf.register("strLen", (s: String) => s.length())
```
我们进入刚才那个register()方法后可以看到
``` java
/**
 * Register a Scala closure of 1 arguments as user-defined function (UDF).
 * @tparam RT return type of UDF.
 * @since 1.3.0
 */
def register[RT: TypeTag, A1: TypeTag](name: String, func: Function1[A1, RT]): UserDefinedFunction = {
  val dataType = ScalaReflection.schemaFor[RT].dataType
  val inputTypes = Try(ScalaReflection.schemaFor[A1].dataType :: Nil).getOrElse(Nil)
  def builder(e: Seq[Expression]) = ScalaUDF(func, dataType, e, inputTypes)
  functionRegistry.registerFunction(name, builder)
  UserDefinedFunction(func, dataType, inputTypes)
}

```

它在编译期通过'上下文绑定‘的方式克服掉‘范型擦除’后，把编译期的‘类型信息’带到了运行时。当拿到了函数对象的参数类型A1和返回值类型RT后，使用这些类型信息完成了UDF的注册。
但是我们根本没有办法使用它，因为方法体的第一行代码的这种‘代码的写法(范型)’已经把我们圈在了编译期。

还好当我们列出UDFRegistration的所有方法后，找到了另一套注册UDF的途径，这些参数是可以在运行时得到的。
``` java
/**
 * Register a user-defined function with 1 arguments.
 * @since 1.3.0
 */
def register(name: String, f: UDF1[_, _], returnType: DataType) = {
  functionRegistry.registerFunction(
    name,
    (e: Seq[Expression]) => ScalaUDF(f.asInstanceOf[UDF1[Any, Any]].call(_: Any), returnType, e)) 
}

```
除了UDF1还有UDF2 ~UDF22
如果在运行时UDF的类已经在classpath下，并且我们知道待注册的UDF的全限定名，便可以完成注册。之前也考虑过通过扫描UDF1等的实现类来省略掉‘全限定名’的依赖，但是最后发现扫出了好多Spark SQL内置的UDF，数量特别多，最后也就没再研究下去。

当我按部就班的通过反射拿到UDF对象后，在获得returnType的路上遇到了问题，没法通过‘方法名’得到相应的方法对象
，按照官网WIKI走不通。。。demo都走不通。。。
``` java

scala> ru.typeOf[Purchase].declaration(ru.TermName("shipped")).asTerm
<console>:14: error: value TermName is not a member of scala.reflect.api.JavaUniverse
              ru.typeOf[Purchase].declaration(ru.TermName("shipped")).asTerm
                                                 ^
```
再又翻了半天源码后，刨出了newTermName方法，有点费劲，不容易，可工作了。
``` java
val alternatives = tpe.declaration(ru.newTermName("call")).asTerm.alternatives
```
然后还得找API，最终是拿到了returnType，这样就可以去自动注册UDF了。
``` java
val returnType = ScalaReflection.schemaFor(rt).dataType
```

这个事情是大概7月份做的，当时也没有行成文字，当写下来时也回忆起当时查各种API的痛苦劲儿，趁着这次的流水帐也梳理了相关的概念，感觉还不错。

[REFLECTION](http://docs.scala-lang.org/overviews/reflection/typetags-manifests.html).
[TypeTags and Manifests](http://docs.scala-lang.org/overviews/reflection/overview.html).


