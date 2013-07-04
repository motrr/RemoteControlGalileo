template<FunctionTemplateParams FunctionSeparator typename RetType>
class FunctionClassName : public FunctionBase
{
public:
    FunctionClassName() {}
    FunctionClassName(const FunctionClassName &other)
    { if(!other.empty()) mInvoker = other.mInvoker->clone(); }

    FunctionClassName(RetType(*func)(FunctionParams)) : mInvoker(new FreeFunctionHolder(func)) {}

    template <class ClassType>
    FunctionClassName(ClassType *object, RetType(ClassType::*func)(FunctionParams)) :
        mInvoker(new MemberFunctionHolder<ClassType>(object, func)) {}

    template <class ClassType>
    FunctionClassName(ClassType *object, RetType(ClassType::*func)(FunctionParams) const) :
        mInvoker(new ConstMemberFunctionHolder<ClassType>(object, func)) {}

#ifdef __APPLE__
    FunctionClassName(id object, SEL selector) : 
        mInvoker(new ObjectiveCMemberFunctionHolder(object, selector)) {}
#endif

    RetType operator ()(FunctionParams) { return mInvoker->invoke(FunctionArgs); }
    FunctionClassName &operator =(const FunctionClassName &other)
    { if(other.empty()) mInvoker.reset(); else mInvoker = other.mInvoker->clone(); return *this; }
    
    bool compare(const FunctionBase &otherBase) const
    {
        const FunctionClassName *other = dynamic_cast<const FunctionClassName*>(&otherBase);
        return other && !empty() && !other->empty() && mInvoker->compare(other->mInvoker.get()); 
    }
    bool operator ==(const FunctionBase &other) const
    {
        return compare(other);
    }
    
    bool empty() const { return !mInvoker.get(); }

private:
    class FunctionHolderBase;
    typedef std::auto_ptr<FunctionHolderBase> Invoker;

    class FunctionHolderBase
    {
    public:
        FunctionHolderBase() {}
        virtual ~FunctionHolderBase() {}

        virtual RetType invoke(FunctionParams) = 0;
        virtual Invoker clone() = 0;
        virtual bool compare(FunctionHolderBase *) const = 0;

    private:
        FunctionHolderBase(const FunctionHolderBase &);
        void operator =(const FunctionHolderBase &);
    };
    
    class FreeFunctionHolder : public FunctionHolderBase
    {
    public:
        typedef RetType(*FunctionT)(FunctionParams);
        FreeFunctionHolder(FunctionT func) : FunctionHolderBase(), mFunction(func) {}

        virtual RetType invoke(FunctionParams) { return mFunction(FunctionArgs); }
        virtual Invoker clone() { return Invoker(new FreeFunctionHolder(mFunction)); }
        virtual bool compare(FunctionHolderBase *otherBase) const
        {
            FreeFunctionHolder *other = dynamic_cast<FreeFunctionHolder*>(otherBase);
            return other && mFunction == other->mFunction;
        }

    private:
        FunctionT mFunction;
    };

    template <class ClassType>
    class MemberFunctionHolder : public FunctionHolderBase
    {
    public:
        typedef RetType (ClassType::*FunctionT)(FunctionParams);
        MemberFunctionHolder(ClassType *object, FunctionT func) : mObject(object), mFunction(func) {}

        virtual RetType invoke(FunctionParams) { return (mObject->*mFunction)(FunctionArgs); }
        virtual Invoker clone() { return Invoker(new MemberFunctionHolder(mObject, mFunction)); }
        virtual bool compare(FunctionHolderBase *otherBase) const
        {
            MemberFunctionHolder *other = dynamic_cast<MemberFunctionHolder*>(otherBase);
            return other && mFunction == other->mFunction && mObject == other->mObject;
        }

    private:
        FunctionT mFunction;
        ClassType *mObject;
    };

    template <class ClassType>
    class ConstMemberFunctionHolder : public FunctionHolderBase
    {
    public:
        typedef RetType (ClassType::*FunctionT)(FunctionParams) const;
        ConstMemberFunctionHolder(ClassType *object, FunctionT func) : mObject(object), mFunction(func) {}

        virtual RetType invoke(FunctionParams) { return (mObject->*mFunction)(FunctionArgs); }
        virtual Invoker clone() { return Invoker(new ConstMemberFunctionHolder(mObject, mFunction)); }
        virtual bool compare(FunctionHolderBase *otherBase) const
        {
            ConstMemberFunctionHolder *other = dynamic_cast<ConstMemberFunctionHolder*>(otherBase);
            return other && mFunction == other->mFunction && mObject == other->mObject;
        }

    private:
        FunctionT mFunction;
        ClassType *mObject;
    };

#ifdef __APPLE__
    class ObjectiveCMemberFunctionHolder : public FunctionHolderBase
    {
    public:
        typedef RetType (*FunctionT)(id, SEL FunctionSeparator FunctionParams);
        ObjectiveCMemberFunctionHolder(id object, SEL selector) : mObject(object), mSelector(selector)
        { mFunction = (FunctionT)class_getMethodImplementation(object_getClass(object), selector); }

        virtual RetType invoke(FunctionParams) { return mFunction(mObject, mSelector FunctionSeparator FunctionArgs); }
        virtual Invoker clone() { return Invoker(new ObjectiveCMemberFunctionHolder(mObject, mSelector)); }
        virtual bool compare(FunctionHolderBase *otherBase) const
        {
            ObjectiveCMemberFunctionHolder *other = dynamic_cast<ObjectiveCMemberFunctionHolder*>(otherBase);
            return other && mFunction == other->mFunction && mObject == other->mObject && mSelector == other->mSelector;
        }

    private:
        FunctionT mFunction;
        SEL mSelector;
        id mObject;
    };
#endif

private:
    Invoker mInvoker;
};

template<FunctionTemplateParams FunctionSeparator typename RetType>
class Function<RetType(FunctionTemplateArgs)> : public FunctionClassName<FunctionTemplateArgs FunctionSeparator RetType>
{
public:
    typedef FunctionClassName<FunctionTemplateArgs FunctionSeparator RetType> BaseType;
    Function() : BaseType() {}
    Function(const Function &other) : BaseType(*static_cast<const BaseType*>(&other)) {}

    Function(RetType(*func)(FunctionParams)) : BaseType(func) {}

    template <class ClassType>
    Function(ClassType *object, RetType(ClassType::*func)(FunctionParams)) : BaseType(object, func) {}

    template <class ClassType>
    Function(ClassType *object, RetType(ClassType::*func)(FunctionParams) const) : BaseType(object, func) {}

#ifdef __APPLE__
    Function(id object, SEL selector) : BaseType(object, selector) {}
#endif

    Function &operator =(const Function &other)
    { *static_cast<BaseType*>(this) = other; return *this; }
};

// bind function like in boost::bind
template <FunctionTemplateParams FunctionSeparator class RetType>
Function<RetType(FunctionTemplateArgs)> bind(RetType(*func)(FunctionParams))
{ return Function<RetType(FunctionTemplateArgs)>(func); }

template <FunctionTemplateParams FunctionSeparator class ClassType, class RetType>
Function<RetType(FunctionTemplateArgs)> bind(ClassType *object, RetType(ClassType::*func)(FunctionParams))
{ return Function<RetType(FunctionTemplateArgs)>(object, func); }

template <FunctionTemplateParams FunctionSeparator class ClassType, class RetType>
Function<RetType(FunctionTemplateArgs)> bind(ClassType *object, RetType(ClassType::*func)(FunctionParams) const)
{ return Function<RetType(FunctionTemplateArgs)>(object, func); }

#ifdef __APPLE__
template<FunctionTemplateParams FunctionSeparator typename RetType>
Function<RetType(FunctionTemplateArgs)> bind(id object, SEL selector)
{ return Function<RetType(FunctionTemplateArgs)>(object, selector); }
#endif