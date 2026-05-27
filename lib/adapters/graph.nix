{ matches }:
{
  mkPredicate =
    selector: ctx: id:
    matches selector id ctx;
  mkSelectPredicate =
    selector: ctx: data:
    matches selector data.id ctx;
}
