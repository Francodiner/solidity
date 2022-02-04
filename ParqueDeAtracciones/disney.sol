// SPDX-License-Identifier: MIT
pragma solidity >=0.4.4 <0.8.0;
pragma experimental ABIEncoderV2;
import "./ERC20.sol";

contract Disney {

    //----------------------- DECLARACIONES INICIALES ----------------------------------------------

    //Instancia del contrato token
    ERC20Basic private token;

    //Direccion de Disney
    address payable public owner;

    constructor() public {
        token = new ERC20Basic(10000);
        owner = msg.sender;

    }

    //Estructura de datos para almacenar a los clientes de Disney
    struct cliente {
        uint tokens_comprados;
        string [] atracciones_disfrutadas;
    }

    //Mapping para el registro de clientes
    mapping (address => cliente) public Clientes;

    //----------------------- GESTION DE TOKENS ----------------------------------------------

    //funcion para establecer el precio de nuestro token
    function PrecioTokens(uint _numTokens) internal pure returns(uint) {
        //Conversion de tokens a ethers: 1 Token -> 1 Ether
        return _numTokens*(1 ether);
    }

    //Funcion para comprar Tokens en disney y subirse a las atracciones
    function CompraTokens(uint _numTokens) public payable {
        uint coste = PrecioTokens(_numTokens);
        //Se evalua el dinero que tiene el cliente para pagar los tokens
        require(msg.value >= coste, "Compra menos tokens o paga con mas ethers");
        //Diferencia de lo que el cliente paga
        uint returnValue = msg.value - coste;
        //Disney retorna la cantidad de ethers que sobra al cliente
        msg.sender.transfer(returnValue);
        //Necesito saber el balance que nos queda de tokens
        uint balance = balanceOf();
        require(_numTokens <= balance, "Compra un numero menor de Tokens");
        //Se transfiere el numero de tokens al cliente
        token.transfer(msg.sender, _numTokens);
        //Registro de los tokens comprados
        Clientes[msg.sender].tokens_comprados += _numTokens;
    }

    //Funcion para saber el balance de los tokens de disney
    function balanceOf() public view returns (uint){
        return token.balanceOf(address(this));
    }

    //Funcion para visualizar el numero de tokens restantes de un cliente
    function MisTokens() public view returns(uint){
        return token.balanceOf(msg.sender);
    }

    //Funcion para generar mas tokens
    function GeneraTokens(uint _numTokens) public Unicamente(msg.sender){
        token.increaseTotalSuply(_numTokens);
    }

    //Modificador para controlar las funciones ejecutables por disney
    modifier Unicamente(address _direccion){
        require(_direccion == owner, "No tienes permisos para ejecutar esta funcion");
        _;
    }
    
    //----------------------- GESTION DE DISNEY ----------------------------------------------

    //Eventos
    event disfruta_atraccion(string);
    event nueva_atraccion(string, string, uint);
    event baja_atraccion(string);
    event alta_atraccion(string);

    //Estructura de datos de la atraccion
    struct atraccion{
        string nombre_atraccion;
        uint precio_atraccion;
        bool estado_atraccion;
    }

    //Mapping para relacionar un nombre de una atraccion con una estructura de datos de la atraccion
    mapping (string => atraccion) public MappingAtracciones;
    
    //Almacenar las atracciones en un array
    string [] Atracciones;

    //Mapping para relacionar una identidad (cliente) con su historial en Disney
    mapping(address => string []) HistorialAtracciones;

    //Star wars -> 2 Tokens
    //Toy Story -> 5 Tokens
    
    //Crear nuevas atracciones, solo es ejecutable por Disney
    function NuevaAtraccion(string memory _nombreAtraccion, uint _precioAtraccion) public Unicamente(msg.sender){
        MappingAtracciones[_nombreAtraccion] = atraccion(_nombreAtraccion, _precioAtraccion, true);
        //Almacenar el nombre de la atraccion en un array
        Atracciones.push(_nombreAtraccion);
        emit nueva_atraccion("Nueva Atraccion: " ,_nombreAtraccion, _precioAtraccion);
    }

    //Dar de baja una atraccion
    function BajaAtraccion(string memory _nombreAtraccion) public Unicamente(msg.sender){
        //El estado de la atraccion pasa a False = no esta en uso
        require(keccak256(bytes(MappingAtracciones[_nombreAtraccion].nombre_atraccion)) != keccak256(bytes("")), "No podes dar de baja una atraccion que no existe");
        MappingAtracciones[_nombreAtraccion].estado_atraccion = false;
         //Emitimos el evento
         emit baja_atraccion(_nombreAtraccion);
    }

    //Volver a dar de alta una atraccion si ya fue arreglada
    function AltaAtraccion(string memory _nombreAtraccion) public Unicamente(msg.sender){
        require(keccak256(bytes(MappingAtracciones[_nombreAtraccion].nombre_atraccion)) != keccak256(bytes("")), "No podes dar de alta una atraccion que no existe");
        require(MappingAtracciones[_nombreAtraccion].estado_atraccion == false, "La atraccion ya se encuentra dada de alta");
        MappingAtracciones[_nombreAtraccion].estado_atraccion = true;
         //Emitimos el evento
         emit alta_atraccion(_nombreAtraccion);
    }

    //Visualizar las atraccion de Disney
    function AtraccionesDisponibles() public view returns(string [] memory){
        return Atracciones;
    }

    //Funcion para subirse a una atraccion de disney y pagar en tokens
    function SubirseAtraccion(string memory _nombreAtraccion) public {
        //Precio de la atraccion (en tokens)
        uint precio_atraccion = MappingAtracciones[_nombreAtraccion].precio_atraccion;
        //Verificamos si existe
        require(keccak256(bytes(MappingAtracciones[_nombreAtraccion].nombre_atraccion)) != keccak256(bytes("")), "No te podes subir a la atraccion porque no existe");
        //Verifica si esta dado de alta
       require(MappingAtracciones[_nombreAtraccion].estado_atraccion == true, "La atraccion no esta disponible");
       //Verifica el numero de tokens que tiene el cliente para subirse a la atraccion
       require(precio_atraccion <= MisTokens(), "Necesitas mas tokens, no te alcanza.");
       token.transferencia_disney(msg.sender, address(this), precio_atraccion);
       HistorialAtracciones[msg.sender].push(_nombreAtraccion);
       emit disfruta_atraccion(_nombreAtraccion);
    }

    //Visualizar el historial de atracciones de un cliente
    function Historial() public view returns(string [] memory){
        return HistorialAtracciones[msg.sender];
    }

    //Funcion para que un cliente de Disney pueda devolver los tokens
    function DevolverTokens(uint _numTokens) public payable{
        //El numero de tokens a devolver sea positivo
        require(_numTokens > 0, "Necesitas devolver una cantidad positiva de tokens");
        //Lo que se esta devolviendo es lo que se tiene
        require(_numTokens <= MisTokens(), "No tienes los tokens que deseas devolver");
        //El cliente devuelve los tokens -> Transferencia de tokens
        token.transferencia_disney(msg.sender, address(this), _numTokens);
        //Devolucion de ethers, disney a cliente
        msg.sender.transfer(PrecioTokens(_numTokens));
    }

    //----------------------- GESTION DE RESTAURANT / COMIDA ----------------------------------------------

    //Estructura de datos de la comida
    struct comida{
        string nombre_plato;
        uint precio_plato;
        bool estado_plato;
    }

    event nuevo_plato(string);

    //Mapping para relacionar un nombre de una comida con una estructura de datos de la comida
    mapping (string => comida) public MappingComidas;
    
    //Almacenar las comidas en un array
    string [] Comidas;

    function CrearPlato(string memory _nombrePlato, uint precio_plato) public Unicamente(msg.sender){
        MappingComidas[_nombrePlato] = comida(_nombrePlato, precio_plato, true);
        Comidas.push(_nombrePlato);
        emit nuevo_plato(_nombrePlato);
    }

}