和数据库的套路一样Spark SQL也提供了对UDF(User-Defined Function)的支持，用以给开发者更灵活的方式去解决特定的问题。
我们知道使用如下的方式便可以完成UDF的注册：一个函数名称和一个函数对象。
sqlContext.udf.register("strLen", (s: String) => s.length())
在2.10以后，Scala已经有了自己的库和工具来支持反射，那么运行时注册UDF也应该是可以实现的。

我们进入刚才那个register()方法后可以看到
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
它在编译期通过'上下文绑定‘的方式克服掉‘范型擦除’后把编译期的‘类型信息’带到了运行时，当拿到了函数对象的参数类型A1和返回值类型RT后，使用这些类型信息完成了UDF的注册。
但是我们根本没有办法使用它，因为方法体的第一行代码的这种‘代码的写法(范型)’已经把我们圈在了编译期。

还好当我们列出UDFRegistration的所有方法后，找到了另一套注册UDF的途径，这些参数是可以在运行时得到的。
下面的UDF1就是Spark SQL UDF的一套接口之一了: org.apache.spark.sql.api.java.UDF1 ~ org.apache.spark.sql.api.java.UDF22
/**
 * Register a user-defined function with 1 arguments.
 * @since 1.3.0
 */
def register(name: String, f: UDF1[_, _], returnType: DataType) = {
  functionRegistry.registerFunction(
    name,
    (e: Seq[Expression]) => ScalaUDF(f.asInstanceOf[UDF1[Any, Any]].call(_: Any), returnType, e))
}

若在运行时UDF的类已经在classpath下，且我们知道待注册的UDF的全限定名，便可以完成自动注册。
因为UDF都继成自Spark的某些接口，所以原来也想过不需了解类名，通过获取到相应接口的实现类的方式来完成注册。但是没法做，因为Spark SQL内置了很多UDF很难处理，也就没在研究下去。
当我按部就班的拿到UDF对象后，在处理returnType时遇到了问题，按照官网WIKI走不通。。。shell都走不通。。。
scala> ru.typeOf[Purchase].declaration(ru.TermName("shipped")).asTerm
<console>:14: error: value TermName is not a member of scala.reflect.api.JavaUniverse
              ru.typeOf[Purchase].declaration(ru.TermName("shipped")).asTerm
                                                 ^
再又翻了半天源码后，刨出了newTermName方法，不容易，工作了。
拿到了val rt = method.returnType。
再刨API，就刨到了我们想要的参数值
val returnType = ScalaReflection.schemaFor(rt).dataType



上面做的事情是大概7月份做的，当时也没有行成文字，当写下来时也回忆起当时查各种API的痛苦劲儿，趁着这次的流水帐也梳理了相关的概念，感觉还不错。


